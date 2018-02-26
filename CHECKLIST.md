- [ ] env vars
  - [ ] make sure non-verbose works
  - [ ] verify that verbose output is helpful
  - [ ] verify that taking `2 > /dev/null` in Simp::RPM was appropriate
- [ ] new tests
  - [ ] test for scriptlet / trigger
  - [ ] built-in simp-adapter scriptlets
  - [ ] scriptlets / triggers
    - [ ] similar triggers should be accepted
    - [ ] duplicate scriptlets should skip later ones
      - [ ] built-in scriptlet should be skipped
      - [ ] later custom scriptlets should be skipped
        - [ ] should these fail?
  - [ ] SIMP-3895 upgrade problem:
    - [ ]  upgrade with triggerun -- foo
    - [ ] install/mock up [simp_rake_helper][srh_src]
    - [ ] test
    - [ ] install pupmod-xxx-foo-1.0.0
    - [ ] upgrade pupmod-xxx-foo-2.0.0
    - [ ] install pupmod-yyy-foo-1.0.0 (obsoletes xxx w/trigger)
    - [ ] upgrade pupmod-yyy-foo-3.0.0 (obsoletes xxx w/trigger)
- [ ] refactor into LUA functions
  - [ ] scriptlet dupe check
- [ ] check for duplicates
- [ ] **REGRESSION** custom/ scripts no longer work

[srh_src]: https://github.com/simp/simp-adapter/blob/master/src/sbin/simp_rpm_helper



For some reason, running `rpm.expand('%{macroname}')` where `macroname` was defined by `%define macronname ...` instead of `%global macroname` ends up causing RPM Lua's to direct subsequent `print()` statements to STDOUT instead of the RPM spec file. (Observed in RPM 4.8.0)