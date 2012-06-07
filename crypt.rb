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
    return nil if opts[:key].nil?
    return nil if opts[:value].nil?

    cipher = OpenSSL::Cipher::Cipher.new('aes-256-cbc')
    cipher.send(method)
    cipher.pkcs5_keyivgen(opts[:key])
    result = cipher.update(opts[:value])
    result << cipher.final

    return result
  end
end