# Занятие № 4   "Загрузка системы"



## Краткое содержание

Порядок загрузки системы
GRUB 2
Параметры ядра
initrd
dracut

## Домашнее задание

Работа с загрузчиком

1. Попасть в систему без пароля несколькими способами

2. Установить систему с LVM, после чего переименовать VG

3. Добавить модуль в initrd

4. (*) Сконфигурировать систему без отдельного раздела с /boot, а только с LVM
   Репозиторий с пропатченым grub: https://yum.rumyantsev.com/centos/7/x86_64/
   PV необходимо инициализировать с параметром --bootloaderareasize 1m

Критерии оценки: Описать действия, описать разницу между методами получения шелла в процессе загрузки.
Где получится - используем script, где не получается - словами или копипастой описываем действия.

------



## Выполнение

#### Заходим в систему без пароля

После запуска виртуальной машины при выборе ядра для загрузки нажимаем **e**. Попадаем в окно где мы можем изменить параметры загрузки

1. Способ, при котором вместо запуска системы инициализации первым процессом запускам shell.

   В конце строки, начинающейся с linux16, добавляем `init=/bin/sh` и нажимаем `сtrl-x` для
   загрузки в систему.

Зашли в систему. Рутовая файловая система при этом монтируется в режиме Read-Only. Если нужно перемонтировать ее в режим Read-Write выполним:

```
mount -o remount,rw /
```

Проверим - запишем данные в любой файл и прочитаем их:

```
sh-4.2# mount -o remount,rw /
sh-4.2# echo 123 > /home/vagrant/test
123
sh-4.2# cat home/vagrant/test
```

2. Способ входа в однопользовательский режим  без включенного доступа привилегированного пользователя. 

В конце строки начинающейся с linux16 добавляем `rd.break` и нажимаем `сtrl-x` для
загрузки в систему. Процесс загрузки будет прерываться перед переходом управления от `initramfs` к `systemd`. После загрузки система перешла в аварийный режим с файловой системой в режиме Read-Only и мы не в корневой файловой системе.

Перемонтируем корневую файловую систему, перейдем в нее, изменим пароль администратора. Создадим файл `/.autorelabel`, чтобы ядро после перезагрузки запустило autorelabeling SELinux.

```
switch_root:/# mount -o remount,rw /sysroot
switch_root:/# chroot /sysroot
sh-4.2# passwd root
sh-4.2# touch /.autorelabel
```

3. Способ загрузки в аварийном режиме. 

В конце строки начинающейся с linux16 заменяем `ro` на `rw init=/sysroot/bin/sh` и нажимаем `сtrl-x` для загрузки в систему.  После загрузки система перешла в аварийный режим. файловая система в режиме `RW` . Чтобы изменить пароль администатора  выполним chroot.

Создадим файл `/.autorelabel`, чтобы ядро после перезагрузки запустило autorelabeling SELinux.

```
:/# chroot /sysroot
:/# passwd root
:/# touch /.autorelabel
:/# exit
:/# reboot
```



#### Переименовываем VG и LV:

Исходное состяние системы :

```
[root@lvm ~]# lsblk
NAME                  MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                     8:0    0   40G  0 disk 
├─sda1                  8:1    0    1M  0 part 
├─sda2                  8:2    0    1G  0 part /boot
└─sda3                  8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                     8:16   0   10G  0 disk 
sdc                     8:32   0    2G  0 disk 
sdd                     8:48   0    1G  0 disk 
sde                     8:64   0    1G  0 disk 
```

Переименуем `VolGroup00` в `OtusRoot`:

```
[root@lvm ~]# vgrename VolGroup00 OtusRoot
  Volume group "VolGroup00" successfully renamed to "OtusRoot"
```

Переименуем `LogVol00` в `lv_root`, а `LogVol01` в `lv_swap`:

```
[root@lvm ~]# lvrename OtusRoot/LogVol00 OtusRoot/lv_root
  Renamed "LogVol00" to "lv_root" in volume group "OtusRoot"

[root@lvm ~]# lvrename OtusRoot/LogVol01 OtusRoot/lv_swap
  Renamed "LogVol01" to "lv_swap" in volume group "OtusRoot"
```

В /etc/fstab, /etc/default/grub, /boot/grub2/grub.cfg  заменяем старое название `VolGroup00` на `OtusRoot`, `LogVol00` на `lv_root`, `LogVol01` на `lv_swap`,

Пересоздаем initrd image, чтобы он знал новое название VG и LV:

```
mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
```

Перезагружаемся и проверяем имя VG:

```
root@lvm ~]# lsblk
NAME                 MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                    8:0    0   40G  0 disk 
├─sda1                 8:1    0    1M  0 part 
├─sda2                 8:2    0    1G  0 part /boot
└─sda3                 8:3    0   39G  0 part 
  ├─OtusRoot-lv_root 253:0    0 37.5G  0 lvm  /
  └─OtusRoot-lv_swap 253:1    0  1.5G  0 lvm  [SWAP]
sdb                    8:16   0   10G  0 disk 
sdc                    8:32   0    2G  0 disk 
sdd                    8:48   0    1G  0 disk 
sde                    8:64   0    1G  0 disk 
```



#### Добавление модулей в initrd:

Скрипты модулей хранятся в каталоге /usr/lib/dracut/modules.d/. Cоздаем в нем каталог с именем 01test:

Содержимое `module-setup.sh`:

```
#!/bin/bash
check() {
    return 0
}
depends() {
    return 0
}
install() {
    inst_hook cleanup 00 "${moddir}/test.sh"
}
```

Содержимое `test.sh`:

```
#!/bin/bash
exec 0<>/dev/console 1<>/dev/console 2<>/dev/console
cat <<'msgend'
Hello! You are in dracut module!
_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ 
< I'm dracut module >
_ _ _ _ _ _ _ _ _ _ _ _ _ _ _ 
   \
    \
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/
msgend
sleep 10
echo " continuing...."
```

`module-setup.sh` - устанавливает модуль и вызывает скрипт `test.sh`

`test.sh` - вызываемый скрипт, в нём у нас рисуется пингвинчик

Пересобираем образ initrd

```
mkinitrd -f -v /boot/initramfs-$(uname -r).img $(uname -r)
# или
dracut -f -v
```

Смотрим какие модули загружены в образ:

```
[root@lvm ~]# lsinitrd -m /boot/initramfs-$(uname -r).img | grep test
test
```

Проверяем:

1. Вариант. Перезагружаемся, руками изменяем параметры загрузки - выключаем опции `rghb` и `quiet`. Продолжаем загрузку - видим пингвина в выводе терминала
2.  Вариант. Редактируем grub.cfg, убрав эти опции. После перезагрузки увилим пингвина

