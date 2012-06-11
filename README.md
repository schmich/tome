## Ward

Ward is a lightweight password manager with a humane command-line interface. It is meant to be simple and secure.

*Disclaimer* I am not a security expert. I've only had limited formal training in security and cryptography.
Now that I've scared off all but the bravest, feel free to look [under the hood](#under-the-hood) or
at the security bits in [crypt.rb](https://github.com/schmich/ward/blob/master/crypt.rb).

## Installation

* Requires [Ruby 1.9.3](http://www.ruby-lang.org/en/downloads/) or newer.
* *Coming soon* `gem install ward`

## Usage

The first time you run `ward`, you'll be asked to create a master password for your encrypted password database.
Any operations involving your password database will require this master password.

    > ward set linkedin.com
    Creating ward database.
    Master password:
    Master password (verify):
    Password:
    Password (verify):
    Created password for linkedin.com.

Recalling a password is easy:

    > ward get linkedin.com
    Master password:
    p4ssw0rd
    
In fact, it's even simpler than that. `ward get` does substring pattern matching to recall a password,
so this works, too:

    > ward get linked
    Master password:
    p4ssw0rd

You can also generate and copy complex passwords without having to remember anything:

    > ward generate last.fm
    Master password:
    Generated password for last.fm.

    > ward get last
    Master password:
    Password for last.fm:
    kizWy76F2@G(21c11(9Tf?f@43B!kq

    > ward copy last
    Master password:
    Password for last.fm copied to clipboard.
    
If you want, you can specify a username with your domain:

    > ward set foo@bar.com baz
    Master password:
    Created password for foo@bar.com.
    
    > ward get bar
    Master password:
    Password for foo@bar.com:
    baz
    
See `ward help` for advanced commands and usage.

## Philosophy

Ward is meant to be simple and secure. Instead of having blind trust in the secure coding practices
of every website you sign up with, you can use ward to help mitigate your risk and exposure.

**Benefits**
* Easily maintain unique per-site passwords.
* Have complex passwords without having to remember them (see `ward generate`).
* If a website leaks your password or its hash, you can quickly generate another unique complex password.
* You can keep track of all of the various websites you have accounts with.

**Drawbacks**
* Single point of failure: if your `.ward` file is compromised, all of your passwords are potentially at risk.
  The encryption on the `.ward` file is meant to mitigate this danger. Brute-force decryption should take significant
  computing power and time. To further reduce risk, don't store usernames (e.g. do `ward set gmail.com` instead of `ward set foo@gmail.com`).
* Dependence on the `.ward` file: if your `.ward` file is lost or corrupt and you forget your passwords, you'll have to reset them.
* If you want access to your passwords on multiple machines, you'll have to sync the `.ward` file somehow.
* Trust in *my* secure coding practices: I encourage you to look at the source yourself.

## Under the hood

All account and password information is stored in a single `.ward` file in the user's home directory. This file is
YAML-formatted and stores the encrypted account and password information along with the encryption parameters.
These encryption parameters, along with the master password, are used to decrypt the password information.

Each time the `.ward` file is modified, new encryption parameters (i.e. the salt and IV) are randomly generated
and used for encryption.

**Password database encryption**
* Encryption algorithm: symmetric [AES-256](http://en.wikipedia.org/wiki/Advanced_Encryption_Standard)
  [CBC](http://en.wikipedia.org/wiki/Block_cipher_modes_of_operation#Cipher-block_chaining_.28CBC.29)
  using the [Ruby OpenSSL library](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/openssl/rdoc/index.html).
* Key derivation:
 * [PBKDF2](http://en.wikipedia.org/wiki/PBKDF2)/[HMAC-SHA-512](http://en.wikipedia.org/wiki/SHA-2) with a master password.
 * [UUID](http://en.wikipedia.org/wiki/UUID)-based random, probabilistically unique [salt](http://en.wikipedia.org/wiki/Salt_%28cryptography%29)
   from [SecureRandom#uuid](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/securerandom/rdoc/SecureRandom.html#method-c-uuid).
 * Randomly-generated [IV](http://en.wikipedia.org/wiki/Initialization_vector) from [OpenSSL::Cipher#random_iv](http://www.ruby-doc.org/stdlib-1.9.3/libdoc/openssl/rdoc/OpenSSL/Cipher.html#method-i-random_iv).
 * 100,000 [key stretch](http://en.wikipedia.org/wiki/Key_stretching) iterations.

## Contributing

*TODO*

## License

*TODO*