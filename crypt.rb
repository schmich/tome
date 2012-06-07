require 'openssl'

class Crypt
  def self.encrypt(opts = {})
    crypt :encrypt, opts
  end

  def self.decrypt(opts = {})
    crypt :decrypt, opts
  end

private
  def self.crypt(method, opts)
    return nil if opts.nil? || opts.empty?
    return nil if opts[:value].nil?
    return nil if opts[:password].nil?

    key = crypt_key(opts[:password])
    value = opts[:value]

    cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    cipher.send(method)
    cipher.pkcs5_keyivgen(key)

    result = cipher.update(value)
    result << cipher.final
    return result
  end

  def self.crypt_key(password)
    key = password
    250000.times {
      key = Digest::SHA256.hexdigest(key)
    }

    return key
  end
end
