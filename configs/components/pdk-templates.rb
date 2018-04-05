component "pdk-templates" do |pkg, settings, platform|
  # Set url and ref from json file so it's easy for jenkins
  # to promote new template versions.
  pkg.load_from_json('configs/components/pdk-templates.json')

  pkg.build_requires "pdk-runtime"
  pkg.build_requires "rubygem-bundler"
  pkg.build_requires "rubygem-mini_portile2"
  pkg.build_requires "rubygem-nokogiri"
  pkg.build_requires "rubygem-pdk"
  pkg.build_requires "puppet-forge-api"

  if platform.is_windows?
    pkg.environment "PATH", settings[:gem_path_env]
  else
    pkg.build_requires "pl-gcc" if platform.is_linux?

    pkg.environment "PATH", "/opt/pl-build-tools/bin:$(PATH)"
  end

  pkg.build do
    git_bin = File.join(settings[:privatedir], 'git', 'bin', 'git')
    pdk_bin = File.join(settings[:ruby_bindir], 'pdk')
    bundle_bin = File.join(settings[:ruby_bindir], 'bundle')
    gem_bin = File.join(settings[:ruby_bindir], 'gem')
    ruby_cachedir = File.join(settings[:cachedir], 'ruby', '2.4.0')

    puppet_cachedir = File.join(settings[:privatedir], 'puppet', 'ruby')
    gem_path_with_puppet_cache = [
      "#{settings[:privatedir]}/ruby/2.4.3/lib/ruby/gems/2.4.0",
      "#{puppet_cachedir}/2.1.0",
      "#{puppet_cachedir}/2.4.0",
    ].join(platform.is_windows? ? ';' : ':')

    if platform.is_windows?
      git_bin = git_bin.gsub(/\/bin\//, '/cmd/').concat('.exe')
      pdk_bin << '.bat'
      bundle_bin << '.bat'
      gem_bin << '.bat'
    end

    # Clone this component repo to a bare repo inside the project cachedir.
    # Need --no-hardlinks because this is a local clone and hardlinks mess up packaging later.
    build_commands = ["#{git_bin} clone --mirror --no-hardlinks . #{File.join(settings[:cachedir], 'pdk-templates.git')}"]

    # Use previously installed pdk gem to generate a new module using the
    # cached module template.
    build_commands << "#{pdk_bin} new module vanagon_module --skip-interview --template-url=file://#{File.join(settings[:cachedir], 'pdk-templates.git')}"

    # Add some additional gems to support experimental features
    build_commands << "echo 'gem \"puppet-debugger\",                            require: false' >> vanagon_module/Gemfile"
    build_commands << "echo 'gem \"guard\",                                      require: false' >> vanagon_module/Gemfile"

    # This pin is needed to ensure Ruby 2.1.9 compat still
    build_commands << "echo 'gem \"listen\", \"~> 3.0.8\",                       require: false' >> vanagon_module/Gemfile"

    build_commands << "echo 'gem \"puppet-strings\",                             require: false' >> vanagon_module/Gemfile"
    build_commands << "echo 'gem \"codecov\",                                    require: false' >> vanagon_module/Gemfile"
    build_commands << "echo 'gem \"license_finder\",                             require: false' >> vanagon_module/Gemfile"

    # Run 'bundle install' in the generated module and cache the gems
    # inside the project cachedir. We add the private/puppet paths to
    # GEM_PATH to avoid installing the puppet gem again.

    # TODO: switch to this once the PDK bundler commands know to look in the puppet_cachedir
    # build_commands << "pushd vanagon_module && GEM_PATH=\"#{gem_path_with_puppet_cache}\" GEM_HOME=\"#{settings[:cachedir]}\" #{bundle_bin} install && popd"

    # TODO: remove this when we active replacement above
    build_commands << "pushd vanagon_module && #{bundle_bin} install --path #{settings[:cachedir]} && popd"

    # Copy generated Gemfile.lock into cachedir.
    build_commands << "cp vanagon_module/Gemfile.lock #{settings[:cachedir]}/Gemfile.lock"

    # TODO: we may not actually need this?
    # Bundle install for each additional ruby version as well, in case we need different versions for a different ruby.
    settings[:additional_rubies].each do |rubyver, local_settings|
      local_bundle_bin = File.join(local_settings[:ruby_bindir], 'bundle')
      local_bundle_bin += '.bat' if platform.is_windows?

      build_commands << "rm vanagon_module/Gemfile.lock"
      build_commands << "pushd vanagon_module && #{local_bundle_bin} install --path #{settings[:cachedir]} && popd"
      build_commands << "cp vanagon_module/Gemfile.lock #{settings[:cachedir]}/Gemfile-#{rubyver}.lock"
    end

    # Install bundler itself into the gem cache
    build_commands << "GEM_HOME=#{ruby_cachedir} #{gem_bin} install ../bundler-#{settings[:bundler_version]}.gem --local --no-document"

    if platform.is_windows?
      # The puppet gem has files in it's 'spec' directory with very long paths which
      # bump up against MAX_PATH on Windows. Since the 'spec' directory is not required
      # at runtime, we just purge it before attempting to package.
      # TODO: this should be unnecessary after switch to cached puppet gems
      build_commands << "/usr/bin/find #{File.join(settings[:cachedir], 'ruby')} -regextype posix-extended -regex '.*/puppet-[[:digit:]]+\.[[:digit:]]+\.[[:digit:]]+[^/]*/spec/.*' -delete"

      build_commands.unshift "GEM_HOME=#{ruby_cachedir} #{gem_bin} install ../nokogiri-#{settings[:nokogiri_version]}-x64-mingw32.gem --local --no-document"
    end

    build_commands.unshift "GEM_HOME=#{ruby_cachedir} #{gem_bin} install ../mini_portile2-#{settings[:mini_portile2_version]}.gem --local --no-document"

    build_commands
  end
end
