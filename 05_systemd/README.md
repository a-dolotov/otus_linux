# Занятие № 5 

# Инициализация системы. Systemd и SysV



## Краткое содержание

Init
SysV services
Systemd

## Домашнее задание

Systemd

Выполнить следующие задания и подготовить развёртывание результата выполнения с использованием Vagrant и Vagrant shell provisioner (или Ansible, на Ваше усмотрение):
1. Написать service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова (файл лога и ключевое слово должны задаваться в /etc/sysconfig);
2. Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi);
3. Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами;
4. *Скачать демо-версию Atlassian Jira и переписать основной скрипт запуска на unit-файл.

## Выполнение

##### 1. Написать сервис, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова. Файл и слово должны задаваться в /etc/sysconfig

Создаём файл `watchlog` с конфигурацией для сервиса в директории `/etc/sysconfig` - из этой конфигурации сервис будет брать необходимые переменные.

```
#Configuration file for my watchlog service
#Place it to /etc/sysconfig
#File and word in that file that we will be monit
WORD="ALERT"
LOG=/var/log/watchlog.log
```

Затем создаем `/var/log/watchlog.log` и пишем туда любые строки включая плюс ключевое слово ‘`ALERT`’

Создадим скрипт `/opt/watchlog.sh`

```
#!/bin/bash
WORD=$1
LOG=$2
DATE=`date`
if grep $WORD $LOG &> /dev/null
then
logger "$DATE: I found word, Master!"
else
exit 0
fi
```

Команда `logger` отправляет лог в системный журнал

Создадим юнит для нашего сервиса `watchlog.service` и разместим его в `/etc/systemd/system/`:

```
[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/sysconfig/watchdog
ExecStart=/opt/watchlog.sh $WORD $LOG
```

Создадим юнит для таймера `watchlog.timer` и разместим его также в `/etc/systemd/system/`:

```
[Unit]
Description=Run watchlog service every 30 second

[Timer]
#Run every 30 second
OnActiveSec=0
OnUnitActiveSec=30
AccuracySec=0
Unit=watchlog.service

[Install]
WantedBy=multi-user.target    
```

Столкнулся с особенностями работы таймера. После  запуска таймера вообще не запускался по расписанию сервис `watchlog.service`. Если же первый раз сервис запустить вручную, то в дальнейшем он уже будет запускаться по таймеру, но время между запусками было не 30 секунд, а около минуты. Решил эти проблемы следующим сопособом:

- Чтобы после запуска таймера  вызывался наш сервис, указал параметр `OnActiveSec=0`;
- Чтобы точность запуска сервиса по тамеру соответстовала значению `OnUnitActiveSec=30`, указал параметр `AccuracySec=0`.

Запускаем таймер `systemctl start watchlog.timer` и смотрим лог `tailf /var/log/messages`:

```
Dec  4 22:31:32 systemd systemd: Started Run watchlog service every 30 second.
Dec  4 22:31:32 systemd systemd: Starting My watchlog service...
Dec  4 22:31:32 systemd systemd: Started My watchlog service.
```

Начинаем писать строки в наш лог `/var/log/watchlog.log` , включая слово ALERT:

```
echo alarm >> /var/log/watchlog.log
echo ALERT >> /var/log/watchlog.log
```

Наблюдаем за логом `tailf /var/log/messages`:

```
Dec  4 22:31:32 systemd systemd: Started Run watchlog service every 30 second.
Dec  4 22:31:32 systemd systemd: Starting My watchlog service...
Dec  4 22:31:32 systemd systemd: Started My watchlog service.
Dec  4 22:32:02 systemd systemd: Starting My watchlog service...
Dec  4 22:32:02 systemd systemd: Started My watchlog service.
Dec  4 22:32:32 systemd systemd: Starting My watchlog service...
Dec  4 22:32:32 systemd systemd: Started My watchlog service.
Dec  4 22:33:03 systemd systemd: Starting My watchlog service...
Dec  4 22:33:03 systemd systemd: Started My watchlog service.
Dec  4 22:33:33 systemd systemd: Starting My watchlog service...
Dec  4 22:33:33 systemd root: Wed Dec  4 22:33:33 UTC 2019: I found word, Master!
Dec  4 22:33:33 systemd systemd: Started My watchlog service.
```



##### 2. Из репозитория epel установить spawn-fcgi и переписать init-скрипт на unit-файл (имя service должно называться так же: spawn-fcgi)

Устанавливаем spawn-fcgi и необходимые для него пакеты:

```
yum install epel-release -y && yum install spawn-fcgi php php-cli mod_fcgid httpd -y
```

`etc/rc.d/init.d/spawn-fcg` - cам Init скрипт, который будем переписывать

Раскомментируем строки с переменными в `/etc/sysconfig/spawn-fcgi`:

```
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u apache -g apache -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"
```

Создадим юнит для нашего сервиса `spawn-fcgi.service` и разместим его в `/etc/systemd/system/`:

```
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/sysconfig/spawn-fcgi
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process

[Install]
WantedBy=multi-user.target
```

Запускаем и проверяем:

```
[root@systemd ~]# systemctl start spawn-fcgi.service 
[root@systemd ~]# systemctl status spawn-fcgi.service
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
   Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; disabled; vendor preset: disabled)
   Active: active (running) since Ср 2019-12-04 22:46:22 UTC; 23s ago
 Main PID: 3493 (php-cgi)
   CGroup: /system.slice/spawn-fcgi.service
           ├─3493 /usr/bin/php-cgi
           ├─3494 /usr/bin/php-cgi
           ├─3495 /usr/bin/php-cgi
           ├─3496 /usr/bin/php-cgi
           ├─3497 /usr/bin/php-cgi
           ├─3498 /usr/bin/php-cgi
           ├─3499 /usr/bin/php-cgi
           ├─3500 /usr/bin/php-cgi
           ├─3501 /usr/bin/php-cgi
           ├─3502 /usr/bin/php-cgi
           ├─3503 /usr/bin/php-cgi
           ├─3504 /usr/bin/php-cgi
           ├─3505 /usr/bin/php-cgi
           ├─3506 /usr/bin/php-cgi
           ├─3507 /usr/bin/php-cgi
           ├─3508 /usr/bin/php-cgi
           ├─3509 /usr/bin/php-cgi
           ├─3510 /usr/bin/php-cgi
           ├─3511 /usr/bin/php-cgi
           ├─3512 /usr/bin/php-cgi
           ├─3513 /usr/bin/php-cgi
           ├─3514 /usr/bin/php-cgi
           ├─3515 /usr/bin/php-cgi
           ├─3516 /usr/bin/php-cgi
           ├─3517 /usr/bin/php-cgi
           ├─3518 /usr/bin/php-cgi
           ├─3519 /usr/bin/php-cgi
           ├─3520 /usr/bin/php-cgi
           ├─3521 /usr/bin/php-cgi
           ├─3522 /usr/bin/php-cgi
           ├─3523 /usr/bin/php-cgi
           ├─3524 /usr/bin/php-cgi
           └─3525 /usr/bin/php-cgi

дек 04 22:46:22 systemd systemd[1]: Started Spawn-fcgi startup service by Otus.
```



##### 3. Дополнить unit-файл httpd (он же apache) возможностью запустить несколько инстансов сервера с разными конфигурационными файлами

Для запуска нескольких экземпляров сервиса будем использовать шаблон `httpd@.service` в конфигурации файла окружения и разместим его в `/etc/systemd/system/`:

```
[Unit]
Description=The Apache HTTP Server
After=network.target remote-fs.target nss-lookup.target
Documentation=man:httpd(8)
Documentation=man:apachectl(8)

[Service]
Type=notify
EnvironmentFile=/etc/sysconfig/httpd-%I
ExecStart=/usr/sbin/httpd $OPTIONS -DFOREGROUND
ExecReload=/usr/sbin/httpd $OPTIONS -k graceful
ExecStop=/bin/kill -WINCH ${MAINPID}
KillSignal=SIGCONT
PrivateTmp=true

[Install]
WantedBy=multi-user.target 
```

В  файлах окружения (их два) задается опция для запуска веб-сервера с необходимым конфигурационным файлом

Первый файл `/etc/sysconfig/httpd-first`:

```
OPTIONS=-f conf/first.conf
```

Второй файл `/etc/sysconfig/httpd-second`:

```
OPTIONS=-f conf/second.conf
```

Соответственно в директории с конфигами `httpd` должны лежать два конфига, в нашем случае это будут `first.conf` и s`econd.conf`.

Для удачного запуска, в конфигурационных файлах должны быть указаны уникальные для каждого экземпляра опции `Listen` и `PidFile`. 

Конфиг первого файла `/etc/httpd/conf/first.conf` копируем с  `/etc/httpd/conf/httpd.conf` и оставляем без изменения. 

Конфиг второго файла `/etc/httpd/conf/second.conf` копируем с  `/etc/httpd/conf/httpd.conf`  и поправим в нем следующие опции:

```
Listen 8080
PidFile /var/run/httpd-second.pid
```

Запускаем сервисы:

```
systemctl start httpd@first
systemctl start httpd@second
```

Смотрим прослушиваемые порты:

```
[root@systemd ~]# ss -tnulp | grep httpd
tcp    LISTEN     0      128      :::8080                 :::*                   users:(("httpd",pid=3742,fd=4),("httpd",pid=3741,fd=4),("httpd",pid=3740,fd=4),("httpd",pid=3739,fd=4),("httpd",pid=3738,fd=4),("httpd",pid=3737,fd=4),("httpd",pid=3736,fd=4))
tcp    LISTEN     0      128      :::80                   :::*                   users:(("httpd",pid=3729,fd=4),("httpd",pid=3728,fd=4),("httpd",pid=3727,fd=4),("httpd",pid=3726,fd=4),("httpd",pid=3725,fd=4),("httpd",pid=3724,fd=4),("httpd",pid=3723,fd=4))
```



##### 4. *Скачать демо-версию Atlassian Jira и переписать основной скрипт запуска на unit-файл.

Скачиваем демо-версию Atlassian Jira:

```
yum install wget -y
wget -q https://downloads.atlassian.com/software/jira/downloads/\
atlassian-jira-software-8.5.1-x64.bin
```

Устанавливать будем с параметрами по умолчанию. 

Для установки `jira` создадим скрипт `install-jira.sh`  с ответами на запросы установщика (в файле только ответы) и запустим:

```
#!/bin/expect -f
set timeout -1
spawn /home/vagrant/atlassian-jira-software-8.5.1-x64.bin
send "y\r"
send "o\r"
send "1\r"
send "i\r"
send "y\r"
expect eof   
```

После установки запустится сервис `jira`. Остановим его:

```
service jira stop
```

`etc/rc.d/init.d/jira` - cам Init скрипт, который будем переписывать

Создадим юнит для нашего сервиса `jira.service` и разместим его в `/etc/systemd/system/`:

```
[Unit]
Description=JIRA Service
After=network.target

[Service]
Type=forking
User=jira
ExecStart=/opt/atlassian/jira/bin/start-jira.sh
ExecRestart=/opt/atlassian/jira/current/bin/stop-jira.sh && \ /opt/atlassian/jira/bin/start-jira.sh
ExecStop=/opt/atlassian/jira/current/bin/stop-jira.sh

[Install]
WantedBy=multi-user.target 
```

Включаем сервис в автостарт и запускаем его:

```
systemctl enable --now jira.service 
```

Проверяем:

```
[vagrant@systemd ~]$ systemctl status jira.service 
● jira.service - JIRA Service
   Loaded: loaded (/etc/systemd/system/jira.service; enabled; vendor preset: disabled)
   Active: active (running) since Вс 2019-12-08 14:55:14 UTC; 23min ago
  Process: 3205 ExecStop=/opt/atlassian/jira/current/bin/stop-jira.sh (code=exited, status=203/EXEC)
  Process: 3214 ExecStart=/opt/atlassian/jira/bin/start-jira.sh (code=exited, status=0/SUCCESS)
 Main PID: 3251 (java)
   CGroup: /system.slice/jira.service
           └─3251 /opt/atlassian/jira/jre//bin/java -Djava.util.logging.config.file=/opt/atlassian/jira/conf/logging.properties -Djava.util.logging.manager=org.apache.juli.ClassLoaderLogManager -Xms384m ...
```

Стартовая страница `jira` http://127.0.0.1:8080 открывается.

Все  это выполнится Vagrant'ом при разворачивании виртуальной машины.



Все  заранее подготовленные скрипты находятся вместе с Vagrantfile в каталоге `scripts`. Vagrant при выполнении  provision разместит их в необходимые каталоги с нужными правами.