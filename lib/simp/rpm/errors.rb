module Simp; end
module Simp::Rpm; end

# rpm command query error
class Simp::Rpm::QueryError < StandardError ; end

# module dependency error
class Simp::Rpm::ModuleDepError < StandardError; end

# module dependency version error
class Simp::Rpm::ModuleDepVersionError < StandardError; end

