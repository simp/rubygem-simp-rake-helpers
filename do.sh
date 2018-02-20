# mimic the beaker setup:
rm -rf /home/build_user/host_files
cp -a /host_files /home/build_user/; chown -R build_user:build_user /home/build_user/host_files

export TERM=xterm
export TOPWD=/home/build_user/host_files
export TWD=${1:-/home/build_user/host_files/spec/acceptance/files/testpackage}
export TWDSPEC="$TWD/dist/tmp/testpackage.spec"
alias  twd="cd $TWD"
rug(){
 runuser build_user -l -c "cd /$TOPWD; $@"
}
ru(){
 runuser build_user -l -c "cd /$TWD; SIMP_RPM_LUA_debug=yes SIMP_RPM_verbose=yes SIMP_PKG_verbose=yes $@"
}
ru_specfile_rpm_q(){
  ru "rpm -q -D 'pup_module_info_dir $TWD' --specfile $TWD/dist/tmp/testpackage.spec $@"
}

# Ensure the new gem is on the system
###rug "bundle update --local || bundle update"
###rug "rake clean"
###rug "rake pkg:install_gem"
###ru "gem cleanup"


# mimic the beaker setup:
ru "rvm use default; bundle update --local || bundle update"
ru "rake clean"
ru "rpm -q -D 'pup_module_info_dir $TWD' --specfile $TWD/dist/tmp/testpackage*.spec"
ru "rake pkg:rpm"  && ru "find dist -name \*noarch.rpm -ls; date" && rpm -qip $TWD/dist/pupmod-simp-testpackage-0.0.1-0.noarch.rpm

## usage:
##
##    source /host_files/do.sh /home/build_user/host_files/spec/acceptance/files/testpackage_custom_scriptlet
##
## ru "rpm -q --queryformat '%{NAME} %{VERSION} %{RELEASE} %{ARCH}\n' --specfile $TWD/dist/tmp/testpackage_custom_scriptlet.spec"
#
#io.stderr:write(content)
#
#
## LUA:
##   oo = rex.newPOSIX('[hc]at')
##  c = oo:match('cat')
##   x, y, z, xx = oo:match('cat hat rat')
##   io.stderr:write('x: '..type(x)..', y: '..type(y)..',z: '..type(z)..', xx: '..type(xx).."\n")
##   io.stderr:write('x: '..x..', y: '..y..',z: '..z..', xx: '..xx.."\n")
##   function tp(_) for key,value in pairs(_) do io.stderr:write("found member " .. key .. ' type: ' .. type(value) .."\n") end end
##   function tpp(_) for key,value in pairs(_) do io.stderr:write("found member '" .. key .. "' type: '" .. type(value) .."' value: '" .. value .."'\n") end end
##   function pp(_, ind)  if not ind then ind = 0 end  if type(_) == 'table' then _ = tp(_) end  if type(_) == 'nil' then _ = "NIL" end   io.stderr:write( ' type: "' .. type(_) ..'", value:\n------\n"'.. _ .. "\n------\n") end 
##   function p(_)   if type(_) == 'table' then io.stderr:write('table length: '..#_..'\n')  tp(_) return end  if type(_) == 'nil' then _ = "NIL" end io.stderr:write(_ .. '\n') end
#r_test(a,b)
#
#function r_test(s,posix_rx)
#  rx = rex.newPOSIX(posix_rx)
#  z = rx:gmatch(a,function(m,c) io.stderr:write('MATCH: '..m)  match = m; captures = c; end)
#  if(z>0) then p('Matched')  p(match) p(captures)  else p('no match for "'..posix_rx..'" in a:\n-----\n'..a..'\n-----\n\n') end
#end
#
##  OMFG: https://fedoraproject.org/wiki/User:Tibbs?rd=JasonTibbitts
#a = "a 123\na 234\nb 456\n ba 789\n a 321\naaa aa aaa"
#b = '^a([^\n])+$'
#b = '^(a[^\b]+?)'
#b = '^(a[^\b]+?$)'
#
#function tp(_) for key,value in pairs(_) do io.stderr:write("found member " .. key .. ' type: ' .. type(value) .."\n") end end
#function tpp(_) for key,value in pairs(_) do io.stderr:write("found member '" .. key .. "' type: '" .. type(value) .."' value: '" .. value .."'\n") end end
#function pp(_, ind)  if not ind then ind = 0 end  if type(_) == 'table' then _ = tp(_) end  if type(_) == 'nil' then _ = "NIL" end   io.stderr:write( ' type: "' .. type(_) ..'", value:\n------\n"'.. _ .. "\n------\n") end 
#function p(_)   if type(_) == 'table' then io.stderr:write('table length: '..#_..'\n')  tp(_) return end  if type(_) == 'nil' then _ = "NIL" end io.stderr:write(_ .. '\n') end
#function r_test(s,posix_rx) rx = rex.newPOSIX(posix_rx) z = rx:gmatch(a,function(m,c)  io.stderr:write('MATCH: "'..m..'"\n') match = m; captures = c; end) if(z>0) then p('Matched! "'..b..'"') p("# match: ") p(match) p('# captures:\n') p (captures)  p("\n") else p('no match for "'..posix_rx..'" in a:\n-----\n'..a..'\n-----\n\n') end end
#r_test(a,b)
#r=r_test
##
##   function p(_) io.stderr:write(_) end
#
#
#
#
# Problem:
# ```
# error: invalid syntax in lua script: [string "<lua>"]:20: '<name>' expected near ':'
#  0< (empty)
# error: line 381: 
# ```
#
# Cause:
#
# ```
# -- note: it's a '::' instead of ':'
# io.stderr::write(' MATCHED')
# ```


