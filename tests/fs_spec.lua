local fs = require("yalms.fs")

describe("yalms.fs", function()
  describe("write_file", function()
    it("writes and returns success", function()
      local path = "/tmp/yalms_test_write.txt"
      local ok, err = fs.write_file(path, "hello")
      assert.is_true(ok)
      assert.is_nil(err)
      os.remove(path)
    end)
  end)

  describe("read_file", function()
    it("reads existing file", function()
      local path = "/tmp/yalms_test_read.txt"
      local f = io.open(path, "w")
      f:write("hello")
      f:close()

      local content, err = fs.read_file(path)
      assert.equal("hello", content)
      assert.is_nil(err)
      os.remove(path)
    end)

    it("returns error for non-existing file", function()
      local content, err = fs.read_file("/tmp/yalms_nonexistent_12345.txt")
      assert.is_nil(content)
      assert.is_not_nil(err)
    end)
  end)
end)
