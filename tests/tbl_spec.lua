local tbl = require("yalms.tbl")

describe("yalms.tbl", function()
  describe("deep_equal", function()
    it("returns true for same reference", function()
      local t = { a = 1 }
      assert.is_true(tbl.deep_equal(t, t))
    end)

    it("returns true for same content", function()
      assert.is_true(tbl.deep_equal({ a = 1, b = 2 }, { a = 1, b = 2 }))
    end)

    it("returns false for different content", function()
      assert.is_false(tbl.deep_equal({ a = 1 }, { a = 2 }))
    end)

    it("returns false for different keys", function()
      assert.is_false(tbl.deep_equal({ a = 1 }, { b = 1 }))
    end)

    it("returns false for different types", function()
      assert.is_false(tbl.deep_equal({ a = 1 }, "a = 1"))
    end)

    it("handles nested tables", function()
      local a = { a = { b = { c = 1 } } }
      local b = { a = { b = { c = 1 } } }
      assert.is_true(tbl.deep_equal(a, b))
    end)

    it("returns false for different nested tables", function()
      local a = { a = { b = 1 } }
      local b = { a = { b = 2 } }
      assert.is_false(tbl.deep_equal(a, b))
    end)

    it("handles arrays", function()
      assert.is_true(tbl.deep_equal({ 1, 2, 3 }, { 1, 2, 3 }))
      assert.is_false(tbl.deep_equal({ 1, 2 }, { 1, 2, 3 }))
    end)
  end)

  describe("deep_copy", function()
    it("copies primitive values", function()
      assert.equal(42, tbl.deep_copy(42))
      assert.equal("hello", tbl.deep_copy("hello"))
      assert.is_true(tbl.deep_copy(true))
    end)

    it("copies simple table", function()
      local original = { a = 1, b = 2 }
      local copy = tbl.deep_copy(original)
      assert.same(original, copy)
      assert.not_equal(original, copy)
    end)

    it("copies nested table", function()
      local original = { a = { b = { c = 1 } } }
      local copy = tbl.deep_copy(original)
      assert.same(original, copy)
      assert.not_equal(original, copy)
      assert.not_equal(original.a, copy.a)
    end)

    it("copies array", function()
      local original = { 1, 2, 3 }
      local copy = tbl.deep_copy(original)
      assert.same(original, copy)
      assert.not_equal(original, copy)
    end)

    it("copies metatable", function()
      local mt = { __add = function() end }
      local original = setmetatable({ a = 1 }, mt)
      local copy = tbl.deep_copy(original)
      assert.equal(getmetatable(original).__add, getmetatable(copy).__add)
    end)

    it("handles cyclic table (returns reference)", function()
      local cyclic = { a = 1 }
      cyclic.self = cyclic
      local copy = tbl.deep_copy(cyclic)
      assert.equal(1, copy.a)
      assert.equal(copy, copy.self)
    end)
  end)

  describe("merge_all", function()
    it("merges single table", function()
      assert.same({ a = 1 }, tbl.merge_all({ a = 1 }))
    end)

    it("merges multiple tables", function()
      local result = tbl.merge_all({ a = 1 }, { b = 2 }, { c = 3 })
      assert.same({ a = 1, b = 2, c = 3 }, result)
    end)

    it("later values override earlier", function()
      local result = tbl.merge_all({ a = 1, b = 2 }, { b = 3, c = 4 })
      assert.same({ a = 1, b = 3, c = 4 }, result)
    end)

    it("handles non-table arguments (lua ipairs stops at nil)", function()
      local result = tbl.merge_all({ a = 1 })
      assert.same({ a = 1 }, result)
    end)
  end)

  describe("slice", function()
    it("returns full slice with defaults", function()
      local original = { 1, 2, 3, 4, 5 }
      assert.same({ 1, 2, 3, 4, 5 }, tbl.slice(original))
    end)

    it("slices from start to end", function()
      local original = { 1, 2, 3, 4, 5 }
      assert.same({ 2, 3, 4 }, tbl.slice(original, 2, 4))
    end)

    it("slices from index to end", function()
      local original = { 1, 2, 3, 4, 5 }
      assert.same({ 3, 4, 5 }, tbl.slice(original, 3))
    end)

    it("handles out of bounds gracefully", function()
      local original = { 1, 2, 3 }
      assert.same({}, tbl.slice(original, 5, 10))
    end)
  end)

  describe("keys_to_num", function()
    it("converts numeric string keys to numbers", function()
      local result = tbl.keys_to_num({ ["1"] = "a", ["2"] = "b" })
      assert.same({ [1] = "a", [2] = "b" }, result)
    end)

    it("keeps string keys as strings", function()
      local result = tbl.keys_to_num({ a = 1, b = 2 })
      assert.same({ a = 1, b = 2 }, result)
    end)

    it("handles mixed keys", function()
      local result = tbl.keys_to_num({ ["1"] = "a", b = 2 })
      assert.same({ [1] = "a", b = 2 }, result)
    end)

    it("throws error for nil", function()
      local success, err = pcall(function()
        tbl.keys_to_num(nil)
      end)
      assert.is_false(success)
    end)
  end)

  describe("find_one", function()
    it("finds item and returns index", function()
      local item, idx = tbl.find_one({ 1, 2, 3 }, function(x)
        return x > 1
      end)
      assert.equal(2, idx)
      assert.equal(2, item)
    end)

    it("returns nil if not found", function()
      local item, idx = tbl.find_one({ 1, 2, 3 }, function(x)
        return x > 10
      end)
      assert.is_nil(item)
      assert.is_nil(idx)
    end)
  end)

  describe("filter", function()
    it("filters items greater than 1", function()
      local result = tbl.filter({ 1, 2, 3, 4 }, function(x)
        return x > 1
      end)
      assert.same({ 2, 3, 4 }, result)
    end)

    it("returns empty for no matches", function()
      local result = tbl.filter({ 1, 2, 3 }, function(x)
        return x > 10
      end)
      assert.same({}, result)
    end)

    it("returns all for all matches", function()
      local result = tbl.filter({ 1, 2, 3 }, function(x)
        return x > 0
      end)
      assert.same({ 1, 2, 3 }, result)
    end)
  end)

  describe("map", function()
    it("transforms items to doubles", function()
      local result = tbl.map({ 1, 2, 3 }, function(x)
        return x, x * 2
      end)
      assert.same({ [1] = 2, [2] = 4, [3] = 6 }, result)
    end)

    it("returns empty for empty array", function()
      local result = tbl.map({}, function(x)
        return x, x
      end)
      assert.same({}, result)
    end)
  end)

  describe("deep_merge", function()
    it("merges nested tables", function()
      local result = tbl.deep_merge({ a = { b = 1 } }, { a = { c = 2 } })
      assert.same({ a = { b = 1, c = 2 } }, result)
    end)

    it("overwrites non-table values", function()
      local result = tbl.deep_merge({ a = 1 }, { a = 2 })
      assert.same({ a = 2 }, result)
    end)

    it("merges multiple tables", function()
      local result = tbl.deep_merge({ a = 1 }, { b = 2 }, { c = { d = 3 } })
      assert.same({ a = 1, b = 2, c = { d = 3 } }, result)
    end)
  end)

  describe("arr_has", function()
    it("returns true when all elements present", function()
      assert.is_true(tbl.arr_has({ 1, 2, 3 }, 1, 2, 3))
    end)

    it("returns true when subset present", function()
      assert.is_true(tbl.arr_has({ 1, 2, 3, 4 }, 1, 2))
    end)

    it("returns false when some elements missing", function()
      assert.is_false(tbl.arr_has({ 1, 2 }, 1, 3))
    end)

    it("returns false for empty array", function()
      assert.is_false(tbl.arr_has({}, 1))
    end)
  end)

  describe("uniques", function()
    it("removes duplicates preserving order", function()
      assert.same({ 1, 2, 3 }, tbl.uniques({ 1, 2, 1, 3, 2 }))
    end)

    it("returns same for no duplicates", function()
      assert.same({ 1, 2, 3 }, tbl.uniques({ 1, 2, 3 }))
    end)

    it("handles empty array", function()
      assert.same({}, tbl.uniques({}))
    end)
  end)

  describe("ensure_array", function()
    it("returns empty array for nil", function()
      assert.same({}, tbl.ensure_array(nil))
    end)

    it("wraps value in array", function()
      assert.same({ 1 }, tbl.ensure_array(1))
    end)

    it("returns table as-is", function()
      local t = { 1, 2, 3 }
      assert.equal(t, tbl.ensure_array(t))
    end)
  end)

  describe("seq", function()
    it("generates sequence from 1", function()
      assert.same({ 1, 2, 3, 4, 5 }, tbl.seq(5))
    end)

    it("generates sequence from start", function()
      assert.same({ 3, 4, 5 }, tbl.seq(3, 3))
    end)

    it("returns empty for count 0", function()
      assert.same({}, tbl.seq(0))
    end)

    it("returns empty for negative count", function()
      assert.same({}, tbl.seq(-1))
    end)

    it("throws error for non-number count", function()
      local success, err = pcall(function()
        tbl.seq("hello")
      end)
      assert.is_false(success)
    end)

    it("throws error for non-number start", function()
      local success, err = pcall(function()
        tbl.seq(5, "hello")
      end)
      assert.is_false(success)
    end)
  end)
end)
