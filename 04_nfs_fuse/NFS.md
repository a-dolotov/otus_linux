# Занятие № 4 "NFS, FUSE"



## Краткое содержание

NFS - версии, процесс, протокол взаимодействия;
параметры сервера;
параметры клиента;
FUSE - принципы работы;
SSHFS - как пример FUSE;
NFS-ganesha.

## Домашнее задание

Vagrant стенд для NFS или SAMBA

NFS

vagrant up должен поднимать 2 виртуалки: сервер и клиент
на сервер должна быть расшарена директория
на клиента она должна автоматически монтироваться при старте (fstab или autofs)
в шаре должна быть папка upload с правами на запись
\- требования для NFS: NFSv3 по UDP, включенный firewall

\* Настроить аутентификацию через KERBEROS

------



## Выполнение



Для демонтрации работы **NFS** и **Kerberos** поднимем vagrantом три виртуалки - **nfskdc** (Key Distribution Center, kadmin), **nfss** (сервер NFS), **nfsc** (клиент NFS).

На клиенте одна шара `share_fstab` будет автоматически монтироваться по UDP, NFSv3. Вторая шара `share_systemd` по TCP (NFSv4) с аутентификацией по протоколу Kerberos



### Необходимые условия для работы Kerberos

Для работы протокола Kerberos необходимы DNS и синхронизация времени.

DNS ипользовать не будем, поэтому добавим FQDN наших хостов в файл  `/etc/hosts` на сервере kdc, сервере nfs, клиенте nfs

При добавлении новой строки в файл `/etc /hosts` нужно написать полное доменное имя **сразу после** IP-адреса. Если использовать один или несколько псевдонимов и добавлять их **перед** полным доменным именем или если  не указать полное доменное имя, **Kerberos** **не** будет работать

```
echo -e "192.168.50.12     nfskdc.testnfs.lan nfskdc\n\
192.168.50.10     nfss.testnfs.lan nfss\n\
192.168.50.11     nfsc.testnfs.lan nfsc"  >> /etc/hosts  
```

Проверим, что синхронизация времени активна. Установим часовой пояс

```bash
timedatectl
timedatectl set-timezone Europe/Moscow
```





### Настройка сервера Key Distribution Center



- Установим пакеты krb5-libs, krb5-server и krb5-workstation

```
yum install -y krb5-libs krb5-server krb5-workstation
```

- Отредактируем  `/etc/krb5.conf и /var/kerberos/krb5kdc/kdc.conf`

Имя домена укажем `testnfs.lan`, имя области `TESTNFS.LAN`

В качестве kdc и admin_server укажем `nfskdc.testnfs.lan`

**/etc/krb5.conf**

```
#Configuration snippets may be placed in this directory as well
includedir /etc/krb5.conf.d/

[logging]
 default = FILE:/var/log/krb5libs.log
 kdc = FILE:/var/log/krb5kdc.log
 admin_server = FILE:/var/log/kadmind.log

[libdefaults]
 dns_lookup_realm = false
 ticket_lifetime = 24h
 renew_lifetime = 7d
 forwardable = true
 rdns = false
 pkinit_anchors = FILE:/etc/pki/tls/certs/ca-bundle.crt
 default_realm = TESTNFS.LAN
 default_ccache_name = KEYRING:persistent:%{uid}

[realms]
TESTNFS.LAN = {
 kdc = nfskdc.testnfs.lan
 admin_server = nfskdc.testnfs.lan
 }

[domain_realm]
.testnfs.lan = TESTNFS.LAN
testnfs.lan = TESTNFS.LAN
```

**/var/kerberos/krb5kdc/kdc.conf**

```
[kdcdefaults]
 kdc_ports = 88
 kdc_tcp_ports = 88

[realms]
 TESTNFS.LAN = {
  master_key_type = aes256-cts
  acl_file = /var/kerberos/krb5kdc/kadm5.acl
  dict_file = /usr/share/dict/words
  admin_keytab = /var/kerberos/krb5kdc/kadm5.keytab
  supported_enctypes = aes256-cts:normal aes128-cts:normal des3-hmac-sha1:normal arcfour-hmac:normal camellia256-cts:normal camellia128-cts:normal des-hmac-sha1:normal des-cbc-md5:normal des-cbc-crc:normal
 }
```

- Создадим базу данных kerberos с помощью  kdb5_util:


```
kdb5_util create -s -r TESTNFS.LAN
```

При появлениии запроса введем и подтвердим пароль. Пароль	**passnfs**

- Создадим принципалы пользователей с правами администратора на доступ к области Kerberos. Например, vagrant и root. При появлениии запроса введем и подтвердим пароль.

```
kadmin.local
addprinc vagrant/admin
addprinc root/admin
quit
```

или

```
kadmin.local -q "addprinc -pw "passvagrant" vagrant/admin"
kadmin.local -q "addprinc -pw "passroot" root/admin"
```

- В файле  `/var/kerberos/krb5kdc/kadm5.acl` укажем пользователей, которые могут удаленно администрировать базу данных kerberos области TESTNFS.LAN. Например, также vagran и root

```
echo -e "root/admin@TESTNFS.LAN\t*\n\
vagrant/admin@TESTNFS.LAN\t*" > /var/kerberos/krb5kdc/kadm5.acl
```

В дальнейшем, если будут добавляться новые записи, то нужно  перечитать ACL, перестартовав севис kadmin

```
systemctl restart kadmin
```

- Добавим сервисные принципалы для  службы nfs для сервера nfss и клиента nfsс со случайным ключом (-randkey) :

```
kadmin.local -q "addprinc -randkey nfs/nfss.testnfs.lan"
kadmin.local -q "addprinc -randkey nfs/nfsc.testnfs.lan" 
```

- Добавим  также принципалы пользователей, которым надо предоставить доступ к шарам nfs. При появлениии запроса введем и подтвердим пароль.  Выполним для пользователя vagrant

```
kadmin.local
addprinc vagrant
quit
```

- Включим и запустим сервисы krb5kdc kadmin


```
systemctl enable --now krb5kdc kadmin
```

- Включим и запустим файервол. Добавим необходимые правила для протокола Kerberos и службы kadmin, перечитаем конфигурацию


```
systemctl enable --now firewalld
firewall-cmd --permanent --add-service=kerberos
firewall-cmd --permanent --add-service=kadmin
firewall-cmd --reload
```





### Настройка сервера NFS



Настроим разрешение имен, проверим синхронизацию времени, установим часовой пояс, как было описано выше.



- #### Установка пакетов

Установим пакеты, необходимые для работы NFS и Kerberos 

```
yum install -y krb5-libs krb5-workstation nfs-utils nfs-utils-lib
```

- #### Настройка Kerberos

Файл конфигурации клиента Kerberos  `/etc/krb5.conf` будет такой же как на сервере KDC

Для возможности работы Kerberos без пароля с использованием секретного ключа нужно сгенерировать keytab

Подключимся к службе kadmin нашего KDC учетной записью, имеющей права на удаленное подключение. Например, root. И сгенерируем krb5.keytab для учетной записи службы nfs/nfss.testnfs

```
kadmin -s nfskdc.testnfs.lan -p root/admin@TESTNFS.LAN -w 'passroot'
ktadd -k /etc/krb5.keytab nfs/nfss.testnfs.lan@TESTNFS.LAN 
quit
```

Посмотреть содержимое файла keytab можно с помощью утилиты **klist**

```
[root@nfss ~]# klist -e -k -t
Keytab name: FILE:/etc/krb5.keytab
KVNO Timestamp         Principal
---- ----------------- --------------------------------------------------------
   2 11/26/20 01:09:08 nfs/nfss.testnfs.lan@TESTNFS.LAN (aes256-cts-hmac-sha1-96) 
   2 11/26/20 01:09:08 nfs/nfss.testnfs.lan@TESTNFS.LAN (aes128-cts-hmac-sha1-96) 
   2 11/26/20 01:09:08 nfs/nfss.testnfs.lan@TESTNFS.LAN (des3-cbc-sha1) 
   2 11/26/20 01:09:08 nfs/nfss.testnfs.lan@TESTNFS.LAN (arcfour-hmac) 
   2 11/26/20 01:09:08 nfs/nfss.testnfs.lan@TESTNFS.LAN (camellia256-cts-cmac) 
   2 11/26/20 01:09:08 nfs/nfss.testnfs.lan@TESTNFS.LAN (camellia128-cts-cmac) 
   2 11/26/20 01:09:08 nfs/nfss.testnfs.lan@TESTNFS.LAN (des-hmac-sha1) 
   2 11/26/20 01:09:08 nfs/nfss.testnfs.lan@TESTNFS.LAN (des-cbc-md5) 
```

- #### Настройка статических портов nfs при включенном firewall

Для NFS v.4  на сервере достаточно открыть порт TCP 2049 

Для NFS  v.2 и v.3 необходимо открыть порты для служб: `portmapper, nfsd, mountd, lockd, statd, rquotad`

Службы `portmapper` и `nfsd` работают на статических портах 111 и 2049 соответсвенно.

Для службы `rquotad` в /etc/services указаны порты 875/tcp и 875/udp

Для служб `mountd, lockd, statd` нужно настроить использование статических портов, раскомментировав соответствующие строки в `/etc/sysconfig/nfs:`

```
LOCKD_TCPPORT=32803
LOCKD_UDPPORT=32769
MOUNTD_PORT=892
STATD_PORT=662
```

Выполним

```
sed -i '/^#LOCKD_TCPPORT/s/#//g' /etc/sysconfig/nfs
sed -i '/^#LOCKD_UDPPORT/s/#//g' /etc/sysconfig/nfs
sed -i '/^#MOUNTD_PORT/s/#//g' /etc/sysconfig/nfs
sed -i '/^#STATD_PORT/s/#//g' /etc/sysconfig/nfs 
```

Включим SECURE_NFS

```
echo 'SECURE_NFS=yes' >> /etc/sysconfig/nfs 
```

- #### Запуск служб

Включим и запустим сервисы `rpcbind nfs-server nfs-lock nfs-idmap nfs-rquotad`

```
systemctl enable --now rpcbind nfs-server nfs-lock nfs-idmap nfs-rquotad
```

Удостоверимся, что службы работают на указанных портах

```
rpcinfo -p
```

- #### Настройка расшариваемых директорий

Создадим два каталога - `/var/share_fstab`  и  `/var/share_systemd`. В обоих каталогах вложенная папка `upload` с правами на запись.

```
mkdir -p /var/share_fstab/upload /var/share_systemd/upload
chmod -R 777 /var/share_fstab/upload /var/share_systemd/upload
chown nfsnobody: -R /var/share_systemd/
```

Добавим созданные каталоги в конфигурационной файл и реэкспортируем все каталоги, казаные в /etc/exports.

Доступ к `/var/share_systemd` будет предоставляться с использование аутентификации по протоколу Kerberos.

```
echo -e "/var/share_fstab  192.168.50.11(rw,sync,no_subtree_check)\n\
/var/share_systemd  nfsc.testnfs.lan(rw,sync,no_subtree_check,sec=krb5,\
anonuid=65534,anongid=65534,all_squash)" >> /etc/exports
exportfs -ra 
```

- #### Настройка firewall

Включим и запустим файервол, добавим необходимые правила для работы NFS и перечитаем конфигурацию

```
systemctl enable --now firewalld
firewall-cmd --permanent --add-port=111/tcp
firewall-cmd --permanent --add-port=111/udp
firewall-cmd --permanent --add-port=2049/tcp
firewall-cmd --permanent --add-port=2049/udp
firewall-cmd --permanent --add-port=32803/tcp
firewall-cmd --permanent --add-port=32769/udp
firewall-cmd --permanent --add-port=892/tcp
firewall-cmd --permanent --add-port=892/udp
firewall-cmd --permanent --add-port=662/tcp
firewall-cmd --permanent --add-port=662/udp
firewall-cmd --permanent --add-port=875/tcp
firewall-cmd --permanent --add-port=875/udp
firewall-cmd --reload  
```





### Настройка клиента NFS



Настроим разрешение имен, проверим синхронизацию времени, установим часовой пояс, как было описано выше.

- #### Установка пакетов

Установим пакеты, необходимые для работы NFS и Kerberos 

```
yum install -y krb5-libs krb5-workstation nfs-utils nfs-utils-lib
```

- #### Настройка Kerberos

Файл конфигурации клиента Kerberos  `/etc/krb5.conf` будет такой же как на сервере KDC

Для возможности работы Kerberos без пароля с использованием секретного ключа нужно сгенерировать keytab

Подключимся к службе kadmin нашего KDC учетной записью, имеющей права на удаленное подключение. Например, root. И сгенерируем krb5.keytab для учетной записи службы nfs/nfsс.testnfs

```
kadmin -s nfskdc.testnfs.lan -p root/admin@TESTNFS.LAN -w 'passroot'
ktadd -k /etc/krb5.keytab nfs/nfsс.testnfs.lan@TESTNFS.LAN vagrant@TESTNFS.LAN 
quit
```

Включим SECURE_NFS

```
echo 'SECURE_NFS=yes' >> /etc/sysconfig/nfs 
```

- #### Создадим каталоги, в которые будут монитороваться NFS

```
mkdir /mnt/share_fstab/ /mnt/share_systemd/  
```

- #### Автоматическое монтирование NFS при старте 

Для автоматического монтирования каталога /var/share_fstab добавим запись в /etc/fstab. Используем UDP и NFSv3

```
echo "192.168.50.10:/var/share_fstab /mnt/share_fstab nfs udp,rw,sync,hard,intr,nfsvers=3,noauto,x-systemd.automount,x-systemd.mount-timeout=30,_netdev 0 0" >> /etc/fstab
```

Для автоматического монтирования каталога /var/share_systemd создадим  systemd юнит `/etc/systemd/system/mnt-share_systemd.mount` . Для подключения nfs используем TCP, NFSv4, аутентификацию по протоколу Kerberos

```
[Unit]
Description=Mount NFS Share
Requires=network-online.target
After=network-online.target

[Mount]
What=nfss.testnfs.lan:/var/share_systemd
Where=/mnt/share_systemd
Type=nfs
Options=rw,sync,hard,intr,sec=krb5

[Install]
WantedBy=multi-user.target
```

Включим и запустим его

```
systemctl daemon-reload
systemctl enable --now mnt-share_systemd.mount
```

- #### Настройка firewall

Включим и запустим файервол. 

```
systemctl enable --now firewalld
```

Перегрузим хост

- #### Работаем с шарами

На клиенте сетевые файловые системы станут доступными при обращении к ним

Доступ к точке монтирования /mnt/share_systemd/ будет иметь только root. Чтобы получить доступ из под другого пользователя, в нашем случае vagrant, нужно получить TGT - билет на получение билетов. Ранее, на KDC мы создали принципал для пользователя vagrant@TESTNFS.LAN

Под пользователем vagrant выполним kinit. На запрос пароля введем пароль от созданного ранее принципала vagrant@TESTNFS.LAN

```
kinit
```

Посмотрим список билетов

```
klist
```

Создадим файлы по 1 Гб на каждой шаре под пользователем vagrant

```
dd if=/dev/zero of=/mnt/share_fstab/upload/testfile bs=1M count=1000 status=progress
dd if=/dev/zero of=/mnt/share_systemd/upload/testfile bs=1M count=1000 status=progress
```

Запись на nfs, смонтированную по udp и NFSv3 происходит в два раза медленней чем на шару, смотированную по TCP NFSv4