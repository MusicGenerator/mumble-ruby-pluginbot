#!/usr/bin/env ruby
# copy@paste from https://gist.github.com/erskingardner/1124645#file-string_ext-rb
class String
  def to_bool
    return true if self == true || self =~ (/(true|t|yes|y|1)$/i)
    return false if self == false || self.nil? || self.empty? || self =~ (/(false|f|no|n|0)$/i)
    raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
  end
end

class Hash
  # Hash deep_diff from https://gist.github.com/henrik/146844
  # Recursively diff two hashes, showing only the differing values.
  # By Henrik Nyh <http://henrik.nyh.se> 2009-07-14 under the MIT license.
  def deep_diff(b)
    a = self
    (a.keys | b.keys).inject({}) do |diff, k|
      if a[k] != b[k]
        if a[k].respond_to?(:deep_diff) && b[k].respond_to?(:deep_diff)
          diff[k] = a[k].deep_diff(b[k])
        else
          diff[k] = [a[k], b[k]]
        end
      end
      diff
    end
  end

  # Modified deep_diff that respond only with keys that are changed in (b)
  def deep_changes(b)
    a = self
    (a.keys | b.keys).inject({}) do |diff, k|
      if a[k] != b[k]
        if a[k].respond_to?(:deep_changes) && b[k].respond_to?(:deep_changes)
          diff[k] = a[k].deep_changes(b[k])
        else
          diff[k] = b[k]
        end
      end
      diff
    end
  end
end
