require 'openssl'
require 'securerandom'

class Crypt
  def self.encrypt(opts = {})
    crypt :encrypt, opts
  end

  def self.decrypt(opts = {})
    crypt :decrypt, opts
  end

  def self.new_iv
    new_cipher.random_iv
  end

  def self.new_salt
    SecureRandom.uuid
  end

private
  def self.new_cipher
    OpenSSL::Cipher::AES.new(256, :CBC)
  end

  def self.crypt(method, opts)
    return nil if opts.nil? || opts.empty? || opts[:value].nil?
    return nil if opts[:password].nil? || opts[:stretch].nil?
    return nil if opts[:iv].nil? || opts[:salt].nil?

    cipher = new_cipher
    cipher.send(method)

    cipher.key = crypt_key(opts)
    cipher.iv = opts[:iv]

    result = cipher.update(opts[:value])
    result << cipher.final
    return result
  end

  def self.crypt_key(opts)
    password = opts[:password]
    salt = opts[:salt]
    iterations = opts[:stretch]
    key_length = 32 # 256 bits
    hash = OpenSSL::Digest::SHA512.new

    return OpenSSL::PKCS5.pbkdf2_hmac(password, salt, iterations, key_length, hash)
  end
end
