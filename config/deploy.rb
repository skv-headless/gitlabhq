require 'rake'

set :stages, %w(production staging)
set :default_stage, "staging"

#set :domain,         'set application domain here'
set :db_adapter,     'postgres' # or mysql
set :mount_point,    '/'
set :application,    'gitlabhq'
set :user,           'git'
set :rails_env,      'production'
set :deploy_to,      "/home/#{user}/apps/#{application}"
set :bundle_without, %w[development test] + (%w[mysql postgres] - [db_adapter])
set :asset_env,      "RAILS_GROUPS=assets RAILS_RELATIVE_URL_ROOT=#{mount_point.sub(/\/+\Z/, '')}"

#set :sidekiq_cmd, "#{bundle_cmd} exec sidekiq"
#set :sidekiqctl_cmd, "#{bundle_cmd} exec sidekiqctl"
#set :sidekiq_timeout, 10
#set :sidekiq_role, :app
#set :sidekiq_pid, "#{current_path}/tmp/pids/sidekiq.pid"
#set :sidekiq_processes, 1

set :application, "gitlab"
set :rvm_type, :system

set :scm, :git
set :repository, "gitorious@git.undev.cc:infrastructure/gitlab.git"

set :use_sudo, false
set :ssh_options, :forward_agent => true
default_run_options[:pty] = true

namespace :deploy do
  desc "Symlinks the database.yml"
  task :symlink_db, :roles => :app do
    run "ln -nfs #{release_path}/config/database.yml.undev #{release_path}/config/database.yml"
  end
  desc "Seed database data"
  task :seed_data do
    run "cd #{current_path} && RAILS_ENV=#{rails_env} #{rake} db:seed"
  end
  desc "Symlinks the gitlab.yml"
  task :symlink_gitlab, :roles => :app do
    run "ln -nfs #{release_path}/config/gitlab.yml.undev #{release_path}/config/gitlab.yml"
  end
  desc "Symlinks the resque.yml"
  task :symlink_resque, :roles => :app do
    run "ln -nfs #{release_path}/config/resque.yml.undev #{release_path}/config/resque.yml"
  end
  desc "Symlinks the unicorn.rb"
  task :symlink_unicorn, :roles => :app do
    run "ln -nfs #{release_path}/config/unicorn.rb.undev #{release_path}/config/unicorn.rb"
  end
end

before 'deploy:finalize_update',
  'deploy:symlink_gitlab',
  'deploy:symlink_resque',
  'deploy:symlink_unicorn'
after "deploy:restart", "unicorn:stop"
after "deploy:update", "deploy:cleanup"
