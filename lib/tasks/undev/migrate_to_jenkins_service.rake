namespace :undev do
  desc "Undev | migrate exist projects to Jenkins service"
  task migrate_to_jenkins: :environment do
    ["admon-ror/admon-func-tests",
     "admon-ror/admon-music-func-tests",
     "admon-ror/admon-ror",
     "admon-ror/audiotag",
     "ads/ads",
     "alehinmemorial/alehinmemorial",
     "Andrew8xx8/jenkins-integration-test",
     "backend/blue7",
     "backend/playout",
     "backend/pyhls",
     "baran-info/baran-info",
     "bloom/bloom",
     "bordeaux/bordeaux",
     "cctv/survapps",
     "cctv/telecircuit",
     "chess/chess",
     "demo-europe/demo-europe",
     "digicast/digicast_rails",
     "digital-october/new_digitaloctober",
     "eurosport-wtcc/wtcc-cc",
     "eurosport-wtcc/wtcc-sfk-apps",
     "forums/forumspb_rails",
     "generations/generations",
     "ibc-epg/epg-sfk-apps",
     "ibc-favorites/favorites_backend_client",
     "ibc-simpletv/simpletv-backend",
     "ibc-simpletv/simpletv-sfk-apps",
     "infrastructure/build-face",
     "infrastructure/redmine",
     "inpicture-video-marking/inpicture-sfk-apps",
     "inpicture-video-marking/movie_sources_proxy",
     "inpicture-video-marking/win32-client-app",
     "kappa/kappa",
     "knowledge-stream/knowledge-stream",
     "ktv-ios/kommersant_club",
     "ktv-ios/web_admin",
     "live_site/live_site",
     "mailer/mailer",
     "media-breach/mb-tv-monitor",
     "megaadmins/ik-chef-clean",
     "mega-highload-platform/elections-exporter-site",
     "mega-highload-platform/vs-admin-face",
     "mega-highload-platform/yandex-coords-tile-generator",
     "mipacademy/mipacademy",
     "mtip/mtip",
     "music-test/music-test",
     "nptv/billing",
     "nptv-demo-apps/knowledgestream-sfk-apps",
     "nptv/dev-center",
     "nptv/face",
     "nptv/oskb-sfk-apps",
     "nptv/sandbox-c",
     "nptv/sfk-apps",
     "nptv/sfk-bootstrap-example",
     "nptv/sfk-bootstrap",
     "nptv/sfk",
     "nptv/sfk-http",
     "nptv/sfk-i18n",
     "nptv/sfk-models",
     "nptv/sfk-rspec",
     "nptv/sfk-templates",
     "nptv-simply-tv/simplytv-sfk-apps",
     "nptv/userbase",
     "olympics2013/olympictorch",
     "party_billing/party_billing",
     "petrolich/iron_daemon",
     "rbc-tv/backend-rbc-tv",
     "rbc-tv/sfk-rbc-tv",
     "receipts/main",
     "rubricator/catagent",
     "rubricator/catstore",
     "rzdtv/ctv",
     "rzdtv/ingest",
     "rzdtv/requestmanager",
     "rzdtv/sql_notification",
     "spief/business-contact-manager",
     "spief/sfk-apps",
     "storage/net-client",
     "teleguide/teleguide-client",
     "teleguide/teleguide-face",
     "teleguide/tvgrid-downloader",
     "telemarker-search/yafts_client",
     "telemarker/telemarker-func-tests",
     "telemarker/telemarker",
     "telemarker/tm-admin",
     "testing-tools/api_testing_lib",
     "testing-tools/api_testing_service",
     "testing-tools/platform-kazan-tests",
     "testing-tools/platform-playout-test",
     "testing-tools/platform-spief-tests",
     "test-project-for-continuous-integration/test-project-for-continuous-integration",
     "tv-market/tv-market",
     "z34/z34",
     "zh/fansite",
     "zh/zhsite",
     "cctv/survapps",
     "ibc-favorites/favorites-backend",
     "spief/business-contact-manager",
     "yakshankin/contentup_acceptance_testing"].each do |project_name|
       project = Project.find_with_namespace(project_name)
       if project
         ci01key = DeployKey.find_by_key(Gitlab.config.services.jenkins.service_keys.production.key)
         if ci01key
           project.deploy_keys_projects.where(deploy_key_id: ci01key).destroy_all
           ci01key.destroy
         end

         ci61key = DeployKey.find_by_key(Gitlab.config.services.jenkins.service_keys.ci_61.key)
         if ci61key
           project.deploy_keys_projects.where(deploy_key_id: ci61key).destroy_all
           ci61key.destroy
         end

         project.create_jenkins_service unless project.jenkins_service.present?
         project.jenkins_service.enable unless project.jenkins_service.enabled?
       end
     end
  end
end
