require 'ward'
require 'test/unit'
require 'tempfile'

class TestWard < Test::Unit::TestCase
  def setup
    password = 'test'
    @temp_store = Tempfile.new('ward')
    @ward = Ward.new(@temp_store.path, password)
  end

  def teardown
    @temp_store.delete rescue nil
  end

  def test_set
    @ward.set(:domain => 'foo.com', :password => 'bar')
  end
end