# A separate connection class for the SQL playground.
#
# Learner SQL must never run on the application's own connection, so it gets
# its own pool authenticated as the restricted sandbox role. Establishing the
# connection on ActiveRecord::Base would repoint the whole application at that
# role, which is why this class exists.
class SqlSandboxRecord < ActiveRecord::Base
  self.abstract_class = true
end
