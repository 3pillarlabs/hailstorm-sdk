#!/usr/bin/env bash

# install hailstorm apps if they have been modified

sudo -i

install_path=/usr/local/lib

# install hailstorm-gem hailstorm-redis
for app in hailstorm-gem hailstorm-redis hailstorm-web; do
	app_sha1=`find /vagrant/$app ! -path '*.git' -type f -exec cat {} + | sha1sum | cut -f1 -d' '`
	install_app='no'
	if [ ! -e $install_path/$app.sha1 ]; then
		install_app='yes'
	else
		app_last_sha1=`cat $install_path/$app.sha1`
		if [ "$app_last_sha1" != "$app_sha1" ]; then
			install_app='yes'
		fi
	fi

	if [ $install_app = 'yes' ]; then
		rm -rf $install_path/$app
		cp -r /vagrant/$app $install_path/
		echo $app_sha1 > $install_path/$app.sha1
		echo "Installed $app"
		if [ $app = 'hailstorm-gem' ]; then
			ruby_version='jruby@hailstorm'
			app_home=$install_path/$app
			vagrant_user=vagrant
			rvm_script_path=/usr/local/rvm/scripts/rvm

			source $rvm_script_path
			cd $install_path
			rvm use $ruby_version

			# install bundler
			which bundle
			if [ $? -ne 0 ]; then
				gem install bundler --no-rdoc --no-ri
			fi

			# install hailstorm-gem & dependencies
			chown -R $vagrant_user:$vagrant_user $app_home
			cd $app_home
			bundle install
			echo $ruby_version > .ruby-version

			# add an alias
			grep 'alias hailstorm-cli' /home/vagrant/.bashrc
			if [ $? -ne 0 ]; then
				sudo -u vagrant sh -c "echo 'alias hailstorm-cli=/usr/local/lib/hailstorm-gem/bin/hailstorm' >> /home/vagrant/.bashrc"
			fi
		fi
	fi
done

exit
