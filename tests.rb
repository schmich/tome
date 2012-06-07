require 'ward'
require 'test/unit'
require 'tempfile'

class TestWard < Test::Unit::TestCase
  def setup
    @temp_store = Tempfile.new('ward')
    @master_password = 'test'
    @ward = new_ward()
  end

  def teardown
    @temp_store.delete rescue nil
  end

  def new_ward
    Ward.new(@temp_store.path, @master_password)
  end

  def test_set
    created = @ward.set(:domain => $dom, :password => $pw)
    assert(created)
  end

  def test_set_get
    @ward.set(:domain => $dom, :password => $pw)
    get = @ward.get(:domain => $dom)
    assert_equal(get, $pw)
  end

  def test_set_update
    created = @ward.set(:domain => $dom, :password => $pw)
    assert(created)
    created = @ward.set(:domain => $dom, :password => $pw)
    assert(!created)
  end

  def test_get_fail
    password = @ward.get(:domain => $dom)
    assert_nil(password)
  end

  def test_set_delete
    created = @ward.set(:domain => $dom, :password => $pw)
    assert(created)
    deleted = @ward.delete(:domain => $dom)
    assert(deleted)
  end

  def test_delete_fail
    deleted = @ward.delete(:domain => $dom)
    assert(!deleted)
  end

  def test_set_delete_get_fail
    created = @ward.set(:domain => $dom, :password => $pw)
    assert(created)
    get = @ward.get(:domain => $dom)
    assert_equal(get, $pw)
    deleted = @ward.delete(:domain => $dom)
    assert(deleted)
    get = @ward.get(:domain => $dom)
    assert_nil(get)
  end

  def test_set_nick
  end

  def test_get_nick
  end

  def test_delete_nick
  end

  def test_nick_unique
  end

  def test_set_alias
  end

  def test_get_alias
  end

  def test_delete_alias
  end

  $dom = 'foo.com'
  $pw = 'bar'
end