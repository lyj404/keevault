Pod::Spec.new do |s|
  s.name             = 'kreepto'
  s.version          = '0.1.0'
  s.summary          = 'KeeStone native crypto engine (Rust).'
  s.description      = <<-DESC
  Rust implementation of KDBX crypto primitives (argon2, aes, chacha20, salsa20)
  exposed to Flutter via dart:ffi. Linked statically into the iOS app so that
  DynamicLibrary.process() resolves the FFI symbols.
                       DESC
  s.homepage         = 'https://github.com/lyj404/keestone'
  s.license          = { :type => 'Apache-2.0', :file => '../LICENSE' }
  s.author           = { 'lyj404' => 'lyj404@proton.me' }
  s.source           = { :path => '.' }

  s.ios.deployment_target = '13.0'
  s.swift_version         = '5.0'

  # Build the Rust static library before the pod is integrated.
  s.prepare_command = 'sh scripts/build_kreepto_ios.sh'

  # The universal static library produced by the prepare_command.
  s.vendored_libraries = 'build/ios/libkreepto.a'

  # No public headers: kpasslib resolves FFI symbols by name at runtime.
  s.source_files = []
  s.preserve_paths = ['build/ios/**/*']

  # Link the C++ runtime some Rust targets depend on.
  s.libraries = 'c++'
end
