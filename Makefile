up:
	docker-compose up

down:
	docker-compose down
	-docker rmi src_database
	-docker rmi src_application

bash_db:
	docker exec -ti info21_db /bin/bash

bash_app:
	docker exec -ti info21_app /bin/bash

clean_db:
	rm -rf ./postgres
	mkdir postgres

rebuild: down clean_db up
