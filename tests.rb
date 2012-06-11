require 'ward'
require 'command'
require 'test/unit'
require 'tempfile'
require 'stringio'
require 'clipboard'
require 'yaml'

class TestWard < Test::Unit::TestCase
  def setup
    @ward_file = Tempfile.new('test')
    @ward = Ward.create!(@ward_file.path, 'test', 10)
  end

  def teardown
    @ward_file.delete rescue nil
  end

  def test_set
    created = @ward.set('foo.com', 'bar')
    assert(created)
  end

  def test_set_no_id_fail
    assert_raise(ArgumentError) {
      @ward.set(nil, 'bar')
    }
  end

  def test_set_no_password_fail
    assert_raise(ArgumentError) {
      @ward.set('foo.com', nil)
    }
  end

  def test_set_find
    @ward.set('foo.com', 'bar')
    matches = @ward.find('foo.com')
    assert_equal('bar', matches['foo.com'])
  end

  def test_set_update
    created = @ward.set('foo.com', 'bar')
    assert(created)
    created = @ward.set('foo.com', 'bar')
    assert(!created)
  end

  def test_find_fail
    matches = @ward.find('foo.com')
    assert_empty(matches)
  end

  def test_set_find_fail
    created = @ward.set('foo.com', 'bar')
    assert(created)
    matches = @ward.find('bar.com')
    assert_empty(matches)
  end

  def test_set_delete
    created = @ward.set('foo.com', 'bar')
    assert(created)
    deleted = @ward.delete('foo.com')
    assert(deleted)
  end

  def test_delete_fail
    deleted = @ward.delete('foo.com')
    assert(!deleted)
  end

  def test_set_delete_find_fail
    created = @ward.set('foo.com', 'bar')
    assert(created)
    matches = @ward.find('foo.com')
    assert_equal('bar', matches['foo.com'])
    deleted = @ward.delete('foo.com')
    assert(deleted)
    matches = @ward.find('foo.com')
    assert_empty(matches)
  end

  def test_many_set_find
    created = @ward.set('foo.com', 'bar')
    assert(created)
    created = @ward.set('baz.com', 'quux')
    assert(created)
    matches = @ward.find('foo.com')
    assert_equal('bar', matches['foo.com'])
    matches = @ward.find('baz.com')
    assert_equal('quux', matches['baz.com'])
  end

  def test_find_pattern
    created = @ward.set('foo@bar.com', 'foo')
    assert(created)
    created = @ward.set('baz@bar.com', 'baz')
    assert(created)
    matches = @ward.find('bar.com')
    assert_equal('foo', matches['foo@bar.com'])
    assert_equal('baz', matches['baz@bar.com'])
  end

  def test_list_fail
    assert_raise(ArgumentError) {
      @ward.each_password
    }
  end

  def test_list_empty
    count = 0
    @ward.each_password {
      count += 1
    }

    assert_equal(0, count)
  end

  def test_set_list
    created = @ward.set('foo@bar.com', 'foo')
    assert(created)
    @ward.each_password { |id, password|
      assert_equal('foo@bar.com', id)
      assert_equal('foo', password)
    }
  end

  def test_ward_exist_fail
    ward_file = Tempfile.new('test')
    exists = Ward.exists?(ward_file.path)
    assert(!exists)
    ward_file.delete rescue nil
  end

  def test_ward_create
    ward_file = Tempfile.new('test')
    ward = Ward.create!(ward_file.path, 'foo', 10)
    exists = Ward.exists?(ward_file.path)
    assert(exists)
    created = ward.set('bar.com', 'foo')
    assert(created)
    ward_file.delete rescue nil
  end

  def test_ward_authenticate_fail
    ward_file = Tempfile.new('test')
    Ward.create!(ward_file.path, 'foo', 10)
    assert_raise(MasterPasswordError) {
      Ward.new(ward_file.path, 'bar')
    }
    ward_file.delete rescue nil
  end

  def test_rename_find
    created = @ward.set('foo', 'bar')
    assert(created)
    matches = @ward.find('foo')
    assert_equal('bar', matches['foo'])
    renamed = @ward.rename('foo', 'quux')
    assert(renamed)
    matches = @ward.find('foo')
    assert_empty(matches)
    matches = @ward.find('quux')
    assert_equal('bar', matches['quux'])
  end

  def test_rename_failed
    rename = @ward.rename('foo', 'bar')
    assert(!rename)
  end
end

# StringIO#noecho does not appear to exist,
# even though it's present on $stdout et al.
# We need to define it for mocking the standard IOs.
class StringIO
  def noecho
    yield self
  end
end

class TestCommand < Test::Unit::TestCase
  def setup
    @ward_file = Tempfile.new('test')
    @ward = Ward.create!(@ward_file.path, 'test', 10)
  end

  def teardown
    @ward_file.delete rescue nil
  end

  def cmd(*args)
    ward_args = args[0...args.length - 1]
    input = args.last

    stdout = StringIO.new('', 'w+')
    stderr = StringIO.new('', 'w+')
    stdin = StringIO.new(input, 'r')
    exit = WardCommand.run(@ward_file.path, ward_args, stdout, stderr, stdin)

    stdout.rewind
    stderr.rewind

    return {
      :exit => exit,
      :out => stdout.read,
      :err => stderr.read
    }
  end

  def test_empty
    c = cmd('', '')
    assert_equal(1, c[:exit])
  end

  def test_invalid_command
    c = cmd('invalid', '')
    assert_equal(1, c[:exit])
  end

  def test_set
    c = cmd('set', 'foo.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
  end

  def test_set_explicit_password
    c = cmd('set', 'foo.com', 'bar', "test\n")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bbar\b/)
  end

  def test_set_overwrite_abort
    c = cmd('set', 'foo.com', 'bar', "test\n")
    assert_equal(0, c[:exit])
    c = cmd('set', 'foo.com', 'baz', "test\nn\n")
    assert_equal(1, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bbar\b/)
  end

  def test_set_overwrite_confirm
    c = cmd('set', 'foo.com', 'bar', "test\n")
    assert_equal(0, c[:exit])
    c = cmd('set', 'foo.com', 'baz', "test\ny\n")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bbaz\b/)
  end

  def test_set_too_few_args
    c = cmd('set', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_set_too_many_args
    c = cmd('set', 'foo.com', 'bar', 'baz', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_generate
    c = cmd('generate', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
  end

  def test_generate_overwrite_abort
    c = cmd('set', 'foo.com', 'foo', "test\n")
    assert_equal(0, c[:exit])
    c = cmd('generate', 'foo.com', "test\nn\n")
    assert_equal(1, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bfoo\b/)
  end

  def test_generate_overwrite_confirm
    c = cmd('set', 'foo.com', 'ImprobableString', "test\n")
    assert_equal(0, c[:exit])
    c = cmd('generate', 'foo.com', "test\ny\n")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] !=~ /\bImprobableString\b/)
  end

  def test_generate_too_few_args
    c = cmd('generate', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_generate_too_many_args
    c = cmd('generate', 'foo.com', 'bar', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_get_exact
    c = cmd('set', 'foo.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bbar\b/)
  end

  def test_get_pattern
    c = cmd('set', 'foo.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bbar\b/)
  end

  def test_get_pattern_multi
    c = cmd('set', 'baz@foo.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('set', 'quux@foo.com', "test\nwaldo\nwaldo")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bbar\b/)
    assert(c[:out] =~ /\bwaldo\b/)
  end

  def test_get_fail
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_get_too_few_args
    c = cmd('get', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_get_too_many_args
    c = cmd('set', 'foo.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo.com', 'bar', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_copy
    c = cmd('set', 'foo.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('copy', 'foo.com', "test\n")
    assert_equal('bar', Clipboard.paste)
  end

  def test_copy_fail
    Clipboard.copy 'baz'
    c = cmd('copy', 'foo.com', "test\n")
    assert_equal(1, c[:exit])
    assert_equal('baz', Clipboard.paste)
  end

  def test_copy_too_few_args
    c = cmd('copy', '')
    assert_equal(1, c[:exit])
  end

  def test_copy_too_many_args
    Clipboard.copy 'baz'
    c = cmd('set', 'foo.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('copy', 'foo.com', 'bar', "test\n")
    assert_equal(1, c[:exit])
    assert_equal('baz', Clipboard.paste)
  end

  def test_list_empty
    c = cmd('list', "test\n")
    assert_equal(0, c[:exit])
  end

  def test_list
    c = cmd('set', 'foo.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('list', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bfoo\.com\b.*\bbar\b/)
  end

  def test_list_multi
    c = cmd('set', 'foo.com', "test\nfoo\nfoo")
    assert_equal(0, c[:exit])
    c = cmd('set', 'bar.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('list', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bfoo\.com\b.*\bfoo\b/)
    assert(c[:out] =~ /\bbar\.com\b.*\bbar\b/)
  end

  def test_list_too_many_args
    c = cmd('list', 'foo', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_delete_confirm
    c = cmd('set', 'foo.com', "test\nfoo\nfoo")
    assert_equal(0, c[:exit])
    c = cmd('delete', 'foo.com', "test\ny\n")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_delete_abort
    c = cmd('set', 'foo.com', "test\nfoo\nfoo")
    assert_equal(0, c[:exit])
    c = cmd('delete', 'foo.com', "test\nn\n")
    assert_equal(1, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bfoo\b/)
  end

  def test_delete_fail
    c = cmd('delete', 'foo.com' "test\n")
    assert_equal(1, c[:exit])
  end

  def test_delete_too_few_args
    c = cmd('delete', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_delete_too_many_args
    c = cmd('set', 'foo.com', "test\nfoo\nfoo")
    assert_equal(0, c[:exit])
    c = cmd('delete', 'foo.com', 'bar', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_rename
    c = cmd('set', 'foo.com', "test\nfoo\nfoo")
    assert_equal(0, c[:exit])
    c = cmd('rename', 'foo.com', 'bar.com', "test\n")
    assert_equal(0, c[:exit])
    c = cmd('get', 'bar.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bfoo\b/)
  end

  def test_rename_fail
    c = cmd('rename', 'foo.com', 'bar.com', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_rename_collide_abort
    c = cmd('set', 'foo.com', "test\nfoo\nfoo")
    assert_equal(0, c[:exit])
    c = cmd('set', 'bar.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('rename', 'foo.com', 'bar.com', "test\nn\n")
    assert_equal(1, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bfoo\b/)
    c = cmd('get', 'bar.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bbar\b/)
  end

  def test_rename_collide_confirm
    c = cmd('set', 'foo.com', "test\nfoo\nfoo")
    assert_equal(0, c[:exit])
    c = cmd('set', 'bar.com', "test\nbar\nbar")
    assert_equal(0, c[:exit])
    c = cmd('rename', 'foo.com', 'bar.com', "test\ny\n")
    assert_equal(0, c[:exit])
    c = cmd('get', 'foo.com', "test\n")
    assert_equal(1, c[:exit])
    c = cmd('get', 'bar.com', "test\n")
    assert_equal(0, c[:exit])
    assert(c[:out] =~ /\bfoo\b/)
  end

  def test_rename_too_few_args
    c = cmd('set', 'foo.com', "test\nfoo\nfoo")
    assert_equal(0, c[:exit])
    c = cmd('rename', 'foo.com', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_rename_too_many_args
    c = cmd('set', 'foo.com', "test\nfoo\nfoo")
    assert_equal(0, c[:exit])
    c = cmd('rename', 'foo.com', 'bar.com', 'baz', "test\n")
    assert_equal(1, c[:exit])
  end

  def test_help
    c = cmd('help', '')
    assert_equal(0, c[:exit])
  end

  def test_help_set
    c = cmd('help', 'set', '')
    assert_equal(0, c[:exit])
  end

  def test_help_fail
    c = cmd('help', 'invalid', '')
    assert_equal(1, c[:exit])
  end

  def test_help_too_many_args
    c = cmd('help', 'set', 'foo', '')
    assert_equal(1, c[:exit])
  end

  def test_set_alias
  end

  def test_generate_alias
  end

  def test_get_alias
  end

  def test_copy_alias
  end

  def test_list_alias
  end

  def test_delete_alias
  end

  def test_rename_alias
  end

  def test_help_alias
  end
end