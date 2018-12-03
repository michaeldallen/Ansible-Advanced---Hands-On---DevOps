### Make
#

BR := echo "" ; echo "..." ; echo ""

make.targets :
	echo "available Make targets:"
	$(MAKE) -pRrq -f $(firstword $(MAKEFILE_LIST)) : 2>/dev/null \
	| awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' \
	| egrep -v '^make.(default|targets)$$' \
	| sed 's/^/    make    /' \
	| sed 's/make    maven.release/make -n maven.release/' \
	| sort

clean :
	find * -name '*~' -exec rm -v {} \;
	find * -name '*.retry' -exec rm -v {} \;
	find * -name '*_inventory.txt' -exec rm -v {} \;

#
### Make

### all
#

all.up : demo.up swa.up

all.down : demo.down swa.down

#
### all

### Docker
#

docker.build : 
	find src/docker -name Dockerfile | \
		while read df ; do \
			tag=`echo $${df} | awk --field-separator / '{print $$(NF-1)}'` ; \
			wd=`dirname $${df}` ; \
			docker build --tag $${tag} $${wd} ; \
		done

docker.prune : all.down
	docker system prune --force 

docker.prune! : all.down
	docker system prune --force --all


#
### Docker



### Demo
#

DEMO_CONTAINER := mmumshad__ubuntu-ssh-enabled

demo.status : demo.inventory
	${BR} ; \
	seq --format='%02g' 1 3 | \
		while read index ; do \
			container_name=${DEMO_CONTAINER}_$${index} ; \
			container_status=`docker ps -a --filter name=$${container_name} --format '{{.Status}}'` ; \
			case "$${container_status}" in \
				Up*) \
					echo "container '$${container_name}' exists and is running" ; \
					;; \
				Exited*) \
					echo "container '$${container_name}' exists and is not running" ; \
					;; \
				*) \
					echo "container '$${container_name}' does not exist" ; \
					;; \
			esac ; \
		done ; \
	${BR} ; \
	docker ps -a --filter name=${DEMO_CONTAINER}* ; \
	${BR} ; \
	seq --format='%02g' 1 3 | \
		while read index ; do \
			container_name=${DEMO_CONTAINER}_$${index} ; \
			docker inspect --format="target$${index} ansible_host={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} ansible_ssh_pass=Passw0rd ansible_ssh_user=root"  $${container_name} ; \
		done > demo_inventory.txt.status ; \
	if cmp --quiet demo_inventory.txt.status demo_inventory.txt ; then \
		echo "'demo_inventory.txt' appears to reflect what is running" ; \
		rm -f demo_inventory.txt.status ; \
	else \
		echo "'demo_inventory.txt' does not appear to reflect what is running" ; \
		mDiff demo_inventory.txt.status demo_inventory.txt ; \
	fi ; \



demo.start :
	seq --format='%02g' 1 3 | \
		while read index ; do \
			container_name=${DEMO_CONTAINER}_$${index} ; \
			container_status=`docker ps -a --filter name=$${container_name} --format '{{.Status}}'` ; \
			case "$${container_status}" in \
				Up*) \
					echo "container '$${container_name}' exists and is running: nothing to do" ; \
					;; \
				Exited*) \
					echo "container '$${container_name}' exists and is not running: starting" ; \
					docker start \
						$${container_name} \
					;; \
				*) \
					echo "container '$${container_name}' does not exist: running" ; \
					docker run \
						--interactive \
						--tty \
						--detach \
						--name $${container_name} \
						${DEMO_CONTAINER} ; \
					;; \
			esac ; \
		done

demo.inventory :
	seq --format='%02g' 1 3 | \
		while read index ; do \
			container_name=${DEMO_CONTAINER}_$${index} ; \
			docker inspect --format="target$${index} ansible_host={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}} ansible_ssh_pass=Passw0rd ansible_ssh_user=root"  $${container_name} ; \
		done | \
		tee demo_inventory.txt



demo.up : docker.build demo.start demo.inventory demo.status

demo.down :
	docker ps --filter 'name=${DEMO_CONTAINER}*' --format 'docker stop {{.Names}}' | sh -x

demo.clean : demo.down
	docker ps --all --filter 'name=${DEMO_CONTAINER}' --format 'docker rm {{.Names}}' | sh -x
	rm -fv demo_inventory.txt ; \
	rm -fv demo_inventory.txt.status ; \

demo.ping : demo.up
	ansible -i demo_inventory.txt -m ping all

#
### Demo


### Simple Web App
#

SWA_CONTAINER := simple_web_app


swa.ping : swa.up
	ansible -i swa_inventory.txt -m ping all

swa.status : swa.inventory
	rm -fv swa_inventory.txt.status ; \
	touch swa_inventory.txt.status ; \
	${BR} ; \
	for container_name in ${SWA_CONTAINER}_01 ${SWA_CONTAINER}_02 ; do \
		container_status=`docker ps -a --filter name=$${container_name} --format '{{.Status}}'` ; \
		case "$${container_status}" in \
			Up*) \
				echo "container '$${container_name}' exists and is running" ; \
				;; \
			Exited*) \
				echo "container '$${container_name}' exists and is not running" ; \
				;; \
			*) \
				echo "container '$${container_name}' does not exist" ; \
				;; \
		esac ; \
	done ; \
	${BR} ; \
	( \
		echo "[db_server]" ; \
		for container_name in ${SWA_CONTAINER}_01 ; do \
			docker inspect --format="$${container_name} ansible_host={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"  $${container_name} ; \
		done ; \
		echo "" ; \
		echo "[web_server]" ; \
		for container_name in ${SWA_CONTAINER}_02 ; do \
			docker inspect --format="$${container_name} ansible_host={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"  $${container_name} ; \
		done ; \
		echo "" ; \
	) >> swa_inventory.txt.status ; \
	${BR} ; \
	docker ps -a --filter name=${SWA_CONTAINER}* ; \
	${BR} ; \
	if cmp --quiet swa_inventory.txt.status swa_inventory.txt ; then \
		echo "'swa_inventory.txt' appears to reflect what is running" ; \
		rm -f swa_inventory.txt.status ; \
	else \
		echo "'swa_inventory.txt' does not appear to reflect what is running" ; \
		mDiff swa_inventory.txt.status swa_inventory.txt ; \
	fi ; \


swa.start : 
	for container_name in ${SWA_CONTAINER}_01 ${SWA_CONTAINER}_02 ; do \
		container_status=`docker ps -a --filter name=$${container_name} --format '{{.Status}}'` ; \
		case "$${container_status}" in \
			Up*) \
				echo "container '$${container_name}' exists and is running: nothing to do" ; \
				;; \
			Exited*) \
				echo "container '$${container_name}' exists and is not running: starting" ; \
				docker start \
					$${container_name} \
				;; \
			*) \
				echo "container '$${container_name}' does not exist: running" ; \
				docker run \
					--interactive \
					--tty \
					--detach \
					--name $${container_name} \
					${SWA_CONTAINER} ; \
				;; \
		esac ; \
	done

swa.inventory :
	( \
		echo "[db_server]" ; \
		for container_name in ${SWA_CONTAINER}_01 ; do \
			docker inspect --format="$${container_name} ansible_host={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"  $${container_name} ; \
		done ; \
		echo "" ; \
		echo "[web_server]" ; \
		for container_name in ${SWA_CONTAINER}_02 ; do \
			docker inspect --format="$${container_name} ansible_host={{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}"  $${container_name} ; \
		done ; \
		echo "" ; \
	) | tee swa_inventory.txt




swa.up : docker.build swa.start swa.inventory swa.status

swa.down :
	docker ps --filter 'name=${SWA_CONTAINER}*' --format 'docker stop {{.Names}}' | sh -x

swa.clean : swa.down
	docker ps --all --filter 'name=${SWA_CONTAINER}' --format 'docker rm {{.Names}}' | sh -x
	rm -fv swa_inventory.txt ; \
	rm -fv swa_inventory.txt.status ; \


swa.play : swa.up 
	ansible-playbook -i swa_inventory.txt swa_playbook.yml

#
### Simple Web Application


