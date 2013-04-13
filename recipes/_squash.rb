# _squash web site

directory "#{node[:squash][:shared_dir]}/config/initializers" do
  owner node[:squash][:user]
  group node[:squash][:group]
  recursive true
  notifies :run, "execute[chown_srv_squash]", :immediately
end

execute "chown_srv_squash" do
  command "chown -R #{node[:squash][:user]}:#{node[:squash][:group]} #{node[:squash][:root_dir]}"
  action :nothing
end

# database.yml
template "#{node[:squash][:shared_dir]}/config/database.yml" do
  owner "deploy"
  group "deploy"
  mode "00600"
  variables :db_host => node.squash.db.host,
  :db_user => node.squash.db.user,
  :db_password => node.postgresql.password.postgres,
  :db_name => node.squash.db.name
end

# secret_token
template "#{node[:squash][:shared_dir]}/secret_token.rb" do
  action :create_if_missing
  owner "deploy"
  group "deploy"
  mode "00600"
  variables :secret => SecureRandom.hex
end

deploy_revision node[:squash][:root_dir] do
  migrate true
  migration_command "bundle exec rake db:migrate --trace"
  environment "RAILS_ENV" => "production"
  repository node.squash.repo
  revision node.squash.revision
  user node[:squash][:user]
  group node[:squash][:group]
  symlinks ({ "secret_token.rb" => "config/initializers/secret_token.rb",
              "config/database.yml" => "config/database.yml",
              "log" => "log",
              "tmp" => "tmp" })

  before_migrate do

    # vendor for jruby
    execute "bundle_jruby" do
      command "bundle config build.pg --with-pg-config=/usr/pgsql-9.2/bin/pg_config &&  bundle install --deployment"
      user node[:squash][:user]
      cwd release_path
      environment ({ 'HOME' => '/home/deploy', 'RBENV_VERSION' => node.squash.jruby.version })
    end

    # vendor for ruby - needed to be able to migrate (jeesh)
    execute "bundle_ruby" do
      command "bundle config build.pg --with-pg-config=/usr/pgsql-9.2/bin/pg_config &&  bundle install --deployment"
      user node[:squash][:user]
      cwd release_path
      environment ({ 'HOME' => '/home/deploy' })
    end
  end
end

# things to do to app to get it to start:
# bundle exec rake assets:precompile

# maybe fork squash and set this up for nginx
# config/environments/production.rb#42
