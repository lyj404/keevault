use aes::cipher::{BlockCipherDecrypt, BlockCipherEncrypt, KeyInit};
use aes::{Aes256, Block};
use argon2::{Algorithm, Argon2, Params, Version};
use chacha20::cipher::{KeyIvInit, StreamCipher, StreamCipherSeek};
use chacha20::ChaCha20;
use salsa20::cipher::{
    NewCipher, StreamCipher as Salsa20StreamCipher, StreamCipherSeek as Salsa20StreamCipherSeek,
};
use salsa20::Salsa20;
use std::convert::TryFrom;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::slice;

const AES_BLOCK_SIZE: usize = 16;
const AES_KEY_SIZE: usize = 32;
const CHACHA20_KEY_SIZE: usize = 32;
const CHACHA20_NONCE_SIZE: usize = 12;
const SALSA20_KEY_SIZE: usize = 32;
const SALSA20_NONCE_SIZE: usize = 8;

/// Runs an FFI body with unwinding contained. A panic must never propagate
/// across the C ABI: it would abort the host process. Requires the
/// `panic = "unwind"` strategy in Cargo.toml to be effective.
fn run_guarded<T>(f: impl FnOnce() -> T) -> Option<T> {
    catch_unwind(AssertUnwindSafe(f)).ok()
}

fn slice_from_ptr<'a>(ptr: *const u8, len: usize) -> &'a [u8] {
    unsafe { slice::from_raw_parts(ptr, len) }
}

fn slice_from_mut_ptr<'a>(ptr: *mut u8, len: usize) -> &'a mut [u8] {
    unsafe { slice::from_raw_parts_mut(ptr, len) }
}

/// Callers pass exactly-sized chunks, so `try_from` cannot fail; the Option
/// keeps the code panic-free even if a chunk length were ever mismatched.
fn aes_block_from_slice(chunk: &[u8]) -> Option<Block> {
    let array = <[u8; AES_BLOCK_SIZE]>::try_from(chunk).ok()?;
    Some(Block::from(array))
}

#[no_mangle]
pub extern "C" fn aes256_transform_block(data: *mut u8, key: *const u8, rounds: u64) {
    if data.is_null() || key.is_null() {
        return;
    }

    run_guarded(|| unsafe { aes256_transform_block_impl(data, key, rounds) });
}

unsafe fn aes256_transform_block_impl(data: *mut u8, key: *const u8, rounds: u64) {
    let block = slice_from_mut_ptr(data, AES_BLOCK_SIZE);
    let key = slice_from_ptr(key, AES_KEY_SIZE);

    let Ok(cipher) = Aes256::new_from_slice(key) else {
        return;
    };
    let Some(mut block_data) = aes_block_from_slice(block) else {
        return;
    };
    for _ in 0..rounds {
        cipher.encrypt_block(&mut block_data);
    }
    block.copy_from_slice(&block_data);
}

#[no_mangle]
pub extern "C" fn aes256_encrypt_cbc(data: *mut u8, data_len: u32, key: *const u8, iv: *const u8) {
    if data.is_null() || key.is_null() || iv.is_null() {
        return;
    }

    run_guarded(|| unsafe { aes256_encrypt_cbc_impl(data, data_len, key, iv) });
}

unsafe fn aes256_encrypt_cbc_impl(data: *mut u8, data_len: u32, key: *const u8, iv: *const u8) {
    let data_len = data_len as usize;
    if !data_len.is_multiple_of(AES_BLOCK_SIZE) {
        return;
    }

    let data = slice_from_mut_ptr(data, data_len);
    let key = slice_from_ptr(key, AES_KEY_SIZE);
    let iv = slice_from_ptr(iv, AES_BLOCK_SIZE);

    let Ok(cipher) = Aes256::new_from_slice(key) else {
        return;
    };
    let mut previous = iv.to_owned();

    for chunk in data.chunks_exact_mut(AES_BLOCK_SIZE) {
        for i in 0..AES_BLOCK_SIZE {
            chunk[i] ^= previous[i];
        }
        let Some(mut block) = aes_block_from_slice(chunk) else {
            return;
        };
        cipher.encrypt_block(&mut block);
        chunk.copy_from_slice(&block);
        previous.copy_from_slice(chunk);
    }
}

#[no_mangle]
pub extern "C" fn aes256_decrypt_cbc(data: *mut u8, data_len: u32, key: *const u8, iv: *const u8) {
    if data.is_null() || key.is_null() || iv.is_null() {
        return;
    }

    run_guarded(|| unsafe { aes256_decrypt_cbc_impl(data, data_len, key, iv) });
}

unsafe fn aes256_decrypt_cbc_impl(data: *mut u8, data_len: u32, key: *const u8, iv: *const u8) {
    let data_len = data_len as usize;
    if !data_len.is_multiple_of(AES_BLOCK_SIZE) {
        return;
    }

    let data = slice_from_mut_ptr(data, data_len);
    let key = slice_from_ptr(key, AES_KEY_SIZE);
    let iv = slice_from_ptr(iv, AES_BLOCK_SIZE);

    let Ok(cipher) = Aes256::new_from_slice(key) else {
        return;
    };
    let mut previous = iv.to_owned();

    for chunk in data.chunks_exact_mut(AES_BLOCK_SIZE) {
        let current_block = chunk.to_owned();
        let Some(mut block) = aes_block_from_slice(chunk) else {
            return;
        };
        cipher.decrypt_block(&mut block);
        for i in 0..AES_BLOCK_SIZE {
            chunk[i] = block[i] ^ previous[i];
        }
        previous.copy_from_slice(&current_block);
    }
}

#[no_mangle]
pub extern "C" fn chacha20_transform(
    data: *mut u8,
    data_len: u32,
    key: *const u8,
    nonce: *const u8,
    counter: u32,
) {
    if data.is_null() || key.is_null() || nonce.is_null() {
        return;
    }

    run_guarded(|| unsafe { chacha20_transform_impl(data, data_len, key, nonce, counter) });
}

unsafe fn chacha20_transform_impl(
    data: *mut u8,
    data_len: u32,
    key: *const u8,
    nonce: *const u8,
    counter: u32,
) {
    let data_len = data_len as usize;
    let data = slice_from_mut_ptr(data, data_len);
    let key = slice_from_ptr(key, CHACHA20_KEY_SIZE);
    let nonce = slice_from_ptr(nonce, CHACHA20_NONCE_SIZE);

    let Ok(mut cipher) = ChaCha20::new_from_slices(key, nonce) else {
        return;
    };
    cipher.seek((counter as u64) << 6);
    cipher.apply_keystream(data);
}

#[no_mangle]
pub extern "C" fn salsa20_transform(
    data: *mut u8,
    data_len: u32,
    key: *const u8,
    nonce: *const u8,
    counter: u64,
) {
    if data.is_null() || key.is_null() || nonce.is_null() {
        return;
    }

    run_guarded(|| unsafe { salsa20_transform_impl(data, data_len, key, nonce, counter) });
}

unsafe fn salsa20_transform_impl(
    data: *mut u8,
    data_len: u32,
    key: *const u8,
    nonce: *const u8,
    counter: u64,
) {
    let data_len = data_len as usize;
    let data = slice_from_mut_ptr(data, data_len);
    let key = slice_from_ptr(key, SALSA20_KEY_SIZE);
    let nonce = slice_from_ptr(nonce, SALSA20_NONCE_SIZE);

    let Ok(mut cipher) = Salsa20::new_from_slices(key, nonce) else {
        return;
    };
    cipher.seek(counter << 6);
    cipher.apply_keystream(data);
}

#[no_mangle]
pub extern "C" fn argon2_hash(
    password: *const u8,
    password_len: u32,
    salt: *const u8,
    salt_len: u32,
    parallelism: u32,
    memory_size_kb: u32,
    iterations: u32,
    hash_len: u32,
    type_: u32,
    version: u32,
    output: *mut u8,
) -> i32 {
    if password.is_null() || salt.is_null() || output.is_null() {
        return -1;
    }

    run_guarded(|| unsafe {
        argon2_hash_impl(
            password,
            password_len,
            salt,
            salt_len,
            parallelism,
            memory_size_kb,
            iterations,
            hash_len,
            type_,
            version,
            output,
        )
    })
    .unwrap_or(-1)
}

#[allow(clippy::too_many_arguments)]
unsafe fn argon2_hash_impl(
    password: *const u8,
    password_len: u32,
    salt: *const u8,
    salt_len: u32,
    parallelism: u32,
    memory_size_kb: u32,
    iterations: u32,
    hash_len: u32,
    type_: u32,
    version: u32,
    output: *mut u8,
) -> i32 {
    if hash_len == 0 {
        return -1;
    }
    let password = slice_from_ptr(password, password_len as usize);
    let salt = slice_from_ptr(salt, salt_len as usize);
    let output = slice_from_mut_ptr(output, hash_len as usize);

    let algorithm = match type_ {
        0 => Algorithm::Argon2d,
        2 => Algorithm::Argon2id,
        _ => return -1,
    };

    let version = match version {
        0x10 => Version::V0x10,
        0x13 => Version::V0x13,
        _ => return -1,
    };

    let params = match Params::new(
        memory_size_kb,
        iterations,
        parallelism,
        Some(hash_len as usize),
    ) {
        Ok(params) => params,
        Err(_) => return -1,
    };

    let argon2 = Argon2::new(algorithm, version, params);

    match argon2.hash_password_into(password, salt, output) {
        Ok(_) => 0,
        Err(_) => -1,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn aes_cbc_round_trip() {
        let mut data = [0x42_u8; AES_BLOCK_SIZE * 2];
        let original = data;
        let key = [0x11_u8; AES_KEY_SIZE];
        let iv = [0x22_u8; AES_BLOCK_SIZE];
        aes256_encrypt_cbc(
            data.as_mut_ptr(),
            data.len() as u32,
            key.as_ptr(),
            iv.as_ptr(),
        );
        assert_ne!(data, original);
        aes256_decrypt_cbc(
            data.as_mut_ptr(),
            data.len() as u32,
            key.as_ptr(),
            iv.as_ptr(),
        );
        assert_eq!(data, original);
    }

    #[test]
    fn stream_ciphers_round_trip() {
        let key = [0x33_u8; CHACHA20_KEY_SIZE];
        let nonce = [0x44_u8; CHACHA20_NONCE_SIZE];
        let mut data = [0x55_u8; 128];
        let original = data;
        chacha20_transform(
            data.as_mut_ptr(),
            data.len() as u32,
            key.as_ptr(),
            nonce.as_ptr(),
            0,
        );
        assert_ne!(data, original);
        chacha20_transform(
            data.as_mut_ptr(),
            data.len() as u32,
            key.as_ptr(),
            nonce.as_ptr(),
            0,
        );
        assert_eq!(data, original);
    }

    #[test]
    fn invalid_cbc_length_is_rejected_without_mutation() {
        let mut data = [0x66_u8; AES_BLOCK_SIZE + 1];
        let original = data;
        let key = [0x77_u8; AES_KEY_SIZE];
        let iv = [0x88_u8; AES_BLOCK_SIZE];
        aes256_encrypt_cbc(
            data.as_mut_ptr(),
            data.len() as u32,
            key.as_ptr(),
            iv.as_ptr(),
        );
        assert_eq!(data, original);
    }

    #[test]
    fn null_pointers_are_rejected() {
        let key = [0x11_u8; AES_KEY_SIZE];
        let iv = [0x22_u8; AES_BLOCK_SIZE];
        aes256_encrypt_cbc(std::ptr::null_mut(), 16, key.as_ptr(), iv.as_ptr());
        aes256_encrypt_cbc(
            [0u8; 16].as_mut_ptr(),
            16,
            std::ptr::null(),
            iv.as_ptr(),
        );
        assert_eq!(
            argon2_hash(
                std::ptr::null(),
                4,
                [0u8; 8].as_ptr(),
                8,
                1,
                1024,
                1,
                32,
                2,
                0x13,
                [0u8; 32].as_mut_ptr(),
            ),
            -1
        );
    }

    #[test]
    fn invalid_argon2_parameters_return_error() {
        let password = [0x61_u8; 4];
        let salt = [0x62_u8; 8];
        let mut output = [0u8; 32];
        // Unknown algorithm type.
        assert_eq!(
            argon2_hash(
                password.as_ptr(),
                password.len() as u32,
                salt.as_ptr(),
                salt.len() as u32,
                1,
                1024,
                1,
                32,
                7,
                0x13,
                output.as_mut_ptr(),
            ),
            -1
        );
        // Unknown version.
        assert_eq!(
            argon2_hash(
                password.as_ptr(),
                password.len() as u32,
                salt.as_ptr(),
                salt.len() as u32,
                1,
                1024,
                1,
                32,
                2,
                0x99,
                output.as_mut_ptr(),
            ),
            -1
        );
        // Zero-length output.
        assert_eq!(
            argon2_hash(
                password.as_ptr(),
                password.len() as u32,
                salt.as_ptr(),
                salt.len() as u32,
                1,
                1024,
                1,
                0,
                2,
                0x13,
                output.as_mut_ptr(),
            ),
            -1
        );
    }

    #[test]
    fn argon2_hash_round_trip() {
        let password = [0x61_u8; 4];
        let salt = [0x62_u8; 8];
        let mut output = [0u8; 32];
        assert_eq!(
            argon2_hash(
                password.as_ptr(),
                password.len() as u32,
                salt.as_ptr(),
                salt.len() as u32,
                1,
                1024,
                1,
                32,
                2,
                0x13,
                output.as_mut_ptr(),
            ),
            0
        );
        assert_ne!(output, [0u8; 32]);
    }

    #[test]
    fn panicking_body_is_contained() {
        // run_guarded must swallow a panic instead of aborting the process.
        assert_eq!(run_guarded(|| -> () { panic!("boom") }), None);
        assert_eq!(run_guarded(|| 42), Some(42));
    }
}
