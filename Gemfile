source 'https://rubygems.org'

gemspec

# grpc ships Windows (x64-mingw-ucrt) precompiled gems only through 1.84.1;
# 1.85.0+ is source-only on Windows and needs a full C/C++ build toolchain.
# Pin it so `bundle install` uses the prebuilt binary (1.84.1 also ships an
# x86_64-linux binary, so CI installs it without compiling). Keep it
# unconditional so the committed Gemfile.lock stays consistent across platforms
# (a conditional pin breaks `bundle install --frozen` on the Linux CI runner).
gem 'grpc', '~> 1.84.1'

group :test do
  gem 'minitest', '~> 5.20'
end
