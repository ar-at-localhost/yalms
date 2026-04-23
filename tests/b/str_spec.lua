local str = require("yalms.str")

describe("yalms.str", function()
  describe("pad_right", function()
    it("pads nil (becomes empty then padded)", function()
      assert.equal("     ", str.pad_right(nil, 5))
    end)

    it("pads empty string", function()
      assert.equal("     ", str.pad_right("", 5))
    end)

    it("pads short string", function()
      assert.equal("hi   ", str.pad_right("hi", 5))
    end)

    it("returns exact length string unchanged", function()
      assert.equal("hello", str.pad_right("hello", 5))
    end)

    it("returns long string unchanged", function()
      assert.equal("hello", str.pad_right("hello", 3))
    end)

    it("uses custom padding character", function()
      assert.equal("hi***", str.pad_right("hi", 5, "*"))
    end)
  end)

  describe("pad_left", function()
    it("pads nil (becomes empty then padded)", function()
      assert.equal("     ", str.pad_left(nil, 5))
    end)

    it("pads empty string", function()
      assert.equal("     ", str.pad_left("", 5))
    end)

    it("pads short string", function()
      assert.equal("   hi", str.pad_left("hi", 5))
    end)

    it("returns exact length string unchanged", function()
      assert.equal("hello", str.pad_left("hello", 5))
    end)

    it("returns long string unchanged", function()
      assert.equal("hello", str.pad_left("hello", 3))
    end)

    it("uses custom padding character", function()
      assert.equal("***hi", str.pad_left("hi", 5, "*"))
    end)
  end)

  describe("pad", function()
    it("pads nil (becomes empty then centered)", function()
      assert.equal("     ", str.pad(nil, 5))
    end)

    it("pads short string with center alignment", function()
      assert.equal(" hi  ", str.pad("hi", 5))
    end)

    it("returns exact length string unchanged", function()
      assert.equal("hello", str.pad("hello", 5))
    end)

    it("returns ellipsis for long string when target <= ellipsis length", function()
      assert.equal("...", str.pad("hello", 3))
    end)

    it("truncates long string with ellipsis when target > ellipsis length", function()
      local result = str.pad("hello", 6)
      assert.is_string(result)
      assert.is_true(#result == 6)
    end)

    it("uses custom padding character", function()
      assert.equal("-hi--", str.pad("hi", 5, "-"))
    end)
  end)

  describe("pad_items", function()
    it("pads empty array", function()
      local padded, max_len = str.pad_items({})
      assert.equal(0, max_len)
      assert.same({}, padded)
    end)

    it("returns exact length for single item (no padding needed)", function()
      local padded, max_len = str.pad_items({ "hi" })
      assert.equal(2, max_len)
      assert.equal("hi", padded["hi"])
    end)

    it("pads multiple items to max length", function()
      local padded, max_len = str.pad_items({ "a", "bb", "ccc" })
      assert.equal(3, max_len)
      assert.is_true(#padded["a"] <= 3)
      assert.is_true(#padded["bb"] <= 3)
      assert.equal("ccc", padded["ccc"])
    end)
  end)

  describe("trim", function()
    it("trims empty string", function()
      assert.equal("", str.trim(""))
    end)

    it("returns string with no spaces unchanged", function()
      assert.equal("hello", str.trim("hello"))
    end)

    it("trims leading spaces", function()
      assert.equal("hello", str.trim("  hello"))
    end)

    it("trims trailing spaces", function()
      assert.equal("hello", str.trim("hello  "))
    end)

    it("trims both leading and trailing spaces", function()
      assert.equal("hello", str.trim("  hello  "))
    end)
  end)

  describe("is_absolute_path", function()
    it("returns true for absolute path", function()
      assert.is_true(str.is_absolute_path("/home/user"))
    end)

    it("returns false for relative path", function()
      assert.is_false(str.is_absolute_path("relative/path"))
    end)

    it("returns false for empty string", function()
      assert.is_false(str.is_absolute_path(""))
    end)

    it("returns nil for nil", function()
      assert.is_nil(str.is_absolute_path(nil))
    end)
  end)

  describe("split", function()
    it("splits by simple separator", function()
      assert.same({ "a", "b", "c" }, str.split("a,b,c", ","))
    end)

    it("returns original string if separator not found", function()
      assert.same({ "hello" }, str.split("hello", ","))
    end)

    it("splits empty string by empty separator into characters", function()
      assert.same({ "h", "e", "l", "l", "o" }, str.split("hello", ""))
    end)

    it("trims when trim option is true", function()
      assert.same({ "a", "b", "c" }, str.split(" a , b , c ", ",", { trim = true }))
    end)

    it("skips empty when skip_empty is true", function()
      assert.same({ "a", "b" }, str.split("a,,b", ",", { skip_empty = true }))
    end)

    it("handles multiple separators", function()
      assert.same({ "one", "two", "three" }, str.split("one:two:three", ":"))
    end)

    it("returns single empty element for empty string with separator", function()
      assert.same({ "" }, str.split("", ","))
    end)
  end)
end)
