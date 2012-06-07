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
    created = @ward.set($dph)
    assert(created)
  end

  def test_set_get
    @ward.set($dph)
    get = @ward.get($dh)
    assert_equal(get, $p)
  end

  def test_set_update
    created = @ward.set($dph)
    assert(created)
    created = @ward.set($dph)
    assert(!created)
  end

  def test_get_fail
    password = @ward.get($dh)
    assert_nil(password)
  end

  def test_set_delete
    created = @ward.set($dph)
    assert(created)
    deleted = @ward.delete($dh)
    assert(deleted)
  end

  def test_delete_fail
    deleted = @ward.delete($dh)
    assert(!deleted)
  end

  def test_set_delete_get_fail
    created = @ward.set($dph)
    assert(created)
    get = @ward.get($dh)
    assert_equal(get, $p)
    deleted = @ward.delete($dh)
    assert(deleted)
    get = @ward.get($dh)
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

  $d = 'foo.com'
  $p = 'bar'
  $dh = { :domain => $d }
  $ph = { :password => $p }
  $dph = $dh.merge($ph)
end

class TestCommand < Test::Unit::TestCase
  def setup
  end

  def teardown
  end

  def test_set
  end
end