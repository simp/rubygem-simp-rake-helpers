%{lua:
src_dir                   = posix.getcwd()
default_scriptlet_content = "/usr/local/sbin/simp_rpm_helper --rpm_dir=%{prefix}/%{module_name} --rpm_section='%{scriptlet_name}' --rpm_status=$1\n\n"

scriptlets_dir = src_dir .. "/scriptlets/"
defined_scriptlets = {}


-- ----------------------------------------------------------------
-- function: define_scriptlet
--
-- arguments:
--
--   scriptlet_name:    name of scriptlet or trigger section
--                      (e.g., 'pre', 'triggerin -- foo')
--   scriptlet_content: normal content of scriptlet
-- ----------------------------------------------------------------
function define_scriptlet (scriptlet_name, scriptlet_content, defined_scriptlets)
  local scriptlet_content = scriptlet_content or ''

  if ( not string.match(scriptlet_name, '^%l') ) then
     io.stderr:write("### WARNING: invalid scriptlet name '"..scriptlet_name.."'\n")
    do return end
  end
  if defined_scriptlets then
    for i,n in ipairs(defined_scriptlets) do
      if (n == scriptlet_name) then
        io.stderr:write("### WARNING: skipped duplicate scriptlet '"..scriptlet_name.."'\n")
        do return end
      end
    end
  end

  scriptlet_content = scriptlet_content:gsub('%%{scriptlet_name}',scriptlet_name)
  scriptlet_content = rpm.expand(scriptlet_content)

  local scriptlet_pattern = "%f[^\n%z]%%" .. scriptlet_name .. "%f[^%w]"
  if not scriptlet_content:match(scriptlet_pattern) then
    print( "\n\n" )
    print( '%' .. scriptlet_name .. "\n" )
  end
  -- print the content into the spec
  print( scriptlet_content.. "\n\n")

  -- add scriptlet name to things we have already defined
  table.insert(defined_scriptlets,scriptlet_name)
end

}
name:           x
Version:        0.0.1
Release:        1%{?dist}
Summary:        Lorem ipsum

License:        Apache 2.0
URL:            http://foo.bar
Source0:        x-0.0.1.tar

#BuildRequires:
#Requires:

%description

It slices!  It dices!  It's a lorem ipsum snookum pookum!

%{lua:

define_scriptlet('preun',
"# when $1 = 1, this is an install\n" ..
"# when $1 = 0, this is an upgrade\n" ..
default_scriptlet_content,
defined_scriptlets )


print "%post\n"
print "# bar\n\n"



things = sources
things = hooks
print('# ~~~~~~~~~~~~~~~~~~~~~~~\n')
if things then
  print('# things: \n')
  for i, s in ipairs(things) do print( '# - '..s..'\n') end
else
  print "WARNING WARNING WARNING: `things` was nil or empty!\n"
end
print('# ~~~~~~~~~~~~~~~~~~~~~~~\n')



if rpm.expand('%{DEBUG_LUA}') then
  io.stderr:write("   #stderr# LUA _specdir = '"..rpm.expand('%{_specdir}').."'\n")
  io.stderr:write("   #stderr# LUA _buildrootdir = '"..rpm.expand('%{_buildrootdir}').."'\n")
  io.stderr:write("   #stderr# LUA buildroot = '"..rpm.expand('%{buildroot}').."'\n")
  io.stderr:write("   #stderr# LUA RPM_BUILD_ROOT = '"..rpm.expand('%{RPM_BUILD_ROOT}').."'\n")
  io.stderr:write("   #stderr# LUA scriptlets_dir = '"..scriptlets_dir.."'\n# ---\n")
end

defined_scriptlets = {}
if (posix.stat(scriptlets_dir, 'type') == 'directory') then
  for i,p in pairs(posix.dir(scriptlets_dir)) do
    local scriptlet_path = scriptlets_dir .. p
    if (posix.stat(scriptlet_path, 'type') == 'regular') then
      local scriptlet_file = io.open(scriptlet_path)
      if scriptlet_file then
        local scriptlet_content = scriptlet_file:read("*all")
        define_scriptlet(p,scriptlet_content, defined_scriptlets)
      else
        io.stderr:write("###LUA: WARNING: could not read "..scriptlet_path.."\n")
     --   print("# WARNING: could not read "..scriptlet_path.."\n")
      end
    end
  end
else
   io.stderr:write("###LUA: not found: " .. scriptlets_dir .. "\n")
end
}
%prep
%setup -q


%build




%clean
rm -rf %{buildroot}


%files
%defattr(-,root,root,-)
%doc

%pre
# foo


%changelog

