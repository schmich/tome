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
    return nil if opts.nil? || opts.empty? || opts[:value].nil? || opts[:password].nil? || opts[:key_stretch].nil?

    key = crypt_key(opts[:password], opts[:key_stretch])
    value = opts[:value]

    cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    cipher.send(method)
    cipher.pkcs5_keyivgen(key)

    result = cipher.update(value)
    result << cipher.final
    return result
  end

  def self.crypt_key(password, key_stretch)
    salt = 'c2e15556-fdcd-4409-b2ec-d3ae4fa1d739'
    
    key = salt + password
    key_stretch.times {
      key = Digest::SHA256.hexdigest(key)
    }

    return key
  end
end
