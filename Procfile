release: rake db:migrate
web: bundle exec puma -t 5:5 -p ${PORT:-3000} -e ${RACK_ENV:-development}
worker: bundle exec shoryuken -r ./workers/material_generation_worker.rb -C ./workers/shoryuken.yml
