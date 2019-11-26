# Занятие № 3   "Файловые системы и LVM"



## Краткое содержание

LVM
\- основные понятия
\- управление и конфигурирование
\- практические примеры
LVM Snapshots
LVM Thin Provision
LVM Cache
LVM MIrror
Файловые системы
Блок, суперблок. айноды
настройки ядра
Журналирование
Иерархия.

## Домашнее задание

Работа с LVM

на имеющемся образе
/dev/mapper/VolGroup00-LogVol00 38G 738M 37G 2% /

уменьшить том под / до 8G
выделить том под /home
выделить том под /var
/var - сделать в mirror
/home - сделать том для снэпшотов
прописать монтирование в fstab
попробовать с разными опциями и разными файловыми системами ( на выбор)
\- сгенерить файлы в /home/
\- снять снэпшот
\- удалить часть файлов
\- восстановится со снэпшота
\- залоггировать работу можно с помощью утилиты script

\* на нашей куче дисков попробовать поставить btrfs/zfs - с кешем, снэпшотами - разметить здесь каталог /opt

Критерии оценки: основная часть обязательна
задание со звездочкой +1 балл

------



## Выполнение

#### Уменьшаем том под / до 8G 

Перед началом работы установим пакет `xfsdump` - он будет необходим для снятия копии / тома

Имеем следующие иcходные данные:

```
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk 
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 
```



##### 1. Подготовим временный том для `/` раздела и скпируем в него все данные с `/`:

Создаем физический том на диске `/dev/sdb`:

```
pvcreate /dev/sdb
```

На физическом томе `/dev/sdb` создаем группу томов c именем `vg_root`:

```
vgcreate vg_root /dev/sdb
```

Создаем логический том с именем `lv_root` и размером 100% от размера созданной группы томов `vg_root`:

```
lvcreate -n lv_root -l +100%FREE /dev/vg_root
```

Проверяем результаты. 

Смотрим какие диски входят в VG `otus`:

```
vgdisplay -v vg_root | grep 'PV Name'
```

Инфорамцию о PV, GV и LV можно получить:

```
pvs

vgs

lvs

pvdisplay

vgdisplay

lvdisplay
```

Создаем на логическом томе `lv_root`  файловую систему `xfs` и смонтируем его, чтобы перенести туда данные:	

```
mkfs.xfs /dev/vg_root/lv_root
mount /dev/vg_root/lv_root /mnt
```

Cкопируем все данные с `/` раздела в `/mnt:`

```
xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
```

Сымитируем текущий root, сделаем в него chroot:

```
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
```

Переконфигурируем grub для того, чтобы при старте перейти в новый `/`:

```
grub2-mkconfig -o /boot/grub2/grub.cfg
```

Обновляем образ initrd:

```
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; \
s/.img//g"` --force; done
```

Для того, чтобы при загрузке был смонтирован нужный root нужно в файле `/boot/grub2/grub.cfg` заменить `rd.lvm.lv=VolGroup00/LogVol00` на `rd.lvm.lv=vg_root/lv_root`:

Выходим из `chrut` и перезагружаемся успешно с новым рут томом. Проверяем это посмотрев результат `lsblk`:

```
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part 
  ├─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol00 253:2    0 37.5G  0 lvm  
sdb                       8:16   0   10G  0 disk 
└─vg_root-lv_root       253:0    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk 
sdd                       8:48   0    1G  0 disk 
sde                       8:64   0    1G  0 disk 
```



##### 2. Изменяем размер старой VG, на которой находился `/`, и возвращаем на него рут:

Удаляем старый логический том размером в 40G и создаем новый на 8G:

```
lvremove /dev/VolGroup00/LogVol00
lvcreate -n VolGroup00/LogVol00 -L 8G /dev/VolGroup00
```

Создаем на логическим томе `LogVol00`  файловую систему `xfs` и смонтируем том, чтобы перенести туда данные:	

```
mkfs.xfs /dev/VolGroup00/LogVol00
mount /dev/VolGroup00/LogVol00 /mnt
```

Cкопируем все данные с `/` раздела в `/mnt:`

```
xfsdump -J - /dev/vg_root/lv_root | xfsrestore -J - /mnt
```

Так же как в первый раз сымитируем текущий root, сделаем в него chroot 

```
for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
chroot /mnt/
```

Переконфигурируем grub, за исключением правки `/etc/grub2/grub.cfg`:

```
grub2-mkconfig -o /boot/grub2/grub.cfg
```

Обновляем образ initrd:

```
cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; \
s/.img//g"` --force; done
```



#### Выделяем том под /var в зеркало: 

Пока не перезагружаемся и не выходим из под chroot переносим `/var` в зеркало

На свободных дисках создаем зеркало:		

```
pvcreate /dev/sdd /dev/sde
vgcreate vg_var /dev/sdd /dev/sde
lvcreate -L 950M -m1 -n lv_var vg_var
```

Создаем на нем файловую систему `ext4` и перемещаем туда `/var`:

```
mkfs.ext4 /dev/vg_var/lv_var
mount /dev/vg_var/lv_var /mnt
cp -aR /var/* /mnt/               #или rsync -avHPSAX /var/ /mnt/
```

На всякий случай сохраняем содержимое старого var (или же можно его просто удалить):

```
mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
```

Монтируем новый var в каталог /var:

```
umount /mnt
mount /dev/vg_var/lv_var /var
```

Правим fstab для автоматического монтирования /var:

```
echo "`blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" >> /etc/fstab
```

Выходим из `chrut` и перезагружаться в новый (уменьшенный root) и удаляем временную Volume Group:

```
lvremove /dev/vg_root/lv_root
vgremove /dev/vg_root
pvremove /dev/sdb
```



#### Выделяем том под /home по тому же принципу что делали для /var:

Создаем логический том `LogVol_Home`, создаем на нем файловую систему и переносим туда `/home`:

```
lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
mkfs.xfs /dev/VolGroup00/LogVol_Home
mount /dev/VolGroup00/LogVol_Home /mnt/
cp -aR /home/* /mnt/
rm -rf /home/*
umount /mnt
mount /dev/VolGroup00/LogVol_Home /home/
```

Правим `/etc/fstab` для автоматического монтирования `/home`:

```
echo "`blkid | grep Home | awk '{print $2}'` /home xfs defaults 0 0" >> /etc/fstab
```

Смотрим результат `lsblk`:

```
NAME                       MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                          8:0    0   40G  0 disk 
├─sda1                       8:1    0    1M  0 part 
├─sda2                       8:2    0    1G  0 part /boot
└─sda3                       8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00    253:0    0    8G  0 lvm  /
  ├─VolGroup00-LogVol01    253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol_Home 253:2    0    2G  0 lvm  /home
sdb                          8:16   0   10G  0 disk 
sdc                          8:32   0    2G  0 disk 
sdd                          8:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_0    253:3    0    4M  0 lvm  
│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0   253:4    0  952M  0 lvm  
  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
sde                          8:64   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1    253:5    0    4M  0 lvm  
│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1   253:6    0  952M  0 lvm  
  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
```



#### Работаем со снапшотами:

Сгенерируем файлы в /home/:

```
touch /home/file{1..20}
```

Создаем снапшот, выделяем под него 100М:

```
lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home
```

Результат выполнения `lsblk`:

```
NAME                            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                               8:0    0   40G  0 disk 
├─sda1                            8:1    0    1M  0 part 
├─sda2                            8:2    0    1G  0 part /boot
└─sda3                            8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00         253:0    0    8G  0 lvm  /
  ├─VolGroup00-LogVol01         253:1    0  1.5G  0 lvm  [SWAP]
  ├─VolGroup00-LogVol_Home-real 253:8    0    2G  0 lvm  
  │ ├─VolGroup00-LogVol_Home    253:2    0    2G  0 lvm  /home
  │ └─VolGroup00-home_snap      253:10   0    2G  0 lvm  
  └─VolGroup00-home_snap-cow    253:9    0  128M  0 lvm  
    └─VolGroup00-home_snap      253:10   0    2G  0 lvm  
sdb                               8:16   0   10G  0 disk 
sdc                               8:32   0    2G  0 disk 
sdd                               8:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_0         253:3    0    4M  0 lvm  
│ └─vg_var-lv_var               253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0        253:4    0  952M  0 lvm  
  └─vg_var-lv_var               253:7    0  952M  0 lvm  /var
sde                               8:64   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1         253:5    0    4M  0 lvm  
│ └─vg_var-lv_var               253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1        253:6    0  952M  0 lvm  
  └─vg_var-lv_var               253:7    0  952M  0 lvm  /var
```

Удаляем часть ранее созданных файлов:

```
rm -f /home/file{1..20}
```

**Восстановление со снапшота:**

```
umount /home
lvconvert --merge /dev/VolGroup00/home_snap
mount /home
```

Проверяем:

```
[root@lvm ~]# ll /home/
total 0
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file1
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file10
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file11
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file12
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file13
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file14
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file15
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file16
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file17
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file18
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file19
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file2
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file20
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file3
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file4
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file5
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file6
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file7
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file8
-rw-r--r--. 1 root    root     0 Nov 23 18:47 file9
drwx------. 3 vagrant vagrant 74 May 12  2018 vagrant
```



#### Изменение размеров томов, файловых систем

Создадим логический том размером 10G. на нем файловую систему ext4 и файл:

```
lvcreate -n LogVol_Data -L 10G /dev/VolGroup00
mkfs.ext4 /dev/VolGroup00/LogVol_Data
mkdir /data
mount /dev/VolGroup00/LogVol_Data /data/
dd if=/dev/zero of=/data/test1.log bs=1M count=5000 status=progress
```

Увеличим размер логического тома LogVol_Data до 15G:

```
lvresize -L 15G /dev/VolGroup00/LogVol_Data
```

Увеличим размера файловой системы до размера логического тома:

```
resize2fs /dev/VolGroup00/LogVol_Data
```

Уменьшим файловую систему до 6G и уменьшим размер тома, на котором она находится:

```
umount /data
e2fsck -fy /dev/VolGroup00/LogVol_Data
resize2fs /dev/VolGroup00/LogVol_Data 6G
lvreduce /dev/VolGroup00/LogVol_Data -L 6G
mount /dev/VolGroup00/LogVol_Data /data/
```



##### Уменьшение размера раздела путем его пересоздания

Создадим раздел на все пространство диска /dev/sdc :

```
fdisk /dev/sdc
n
p
1
w
```

Создадим на этом раздеде файловую систему

```
mkfs.ext4 /dev/sdc1 
```

Смонтируем в /data2/ и создадим файл log.log размером 500МB:

```
mkdir /data2
mount /dev/sdc1 /data2/
dd if=/dev/zero of=/data2/log.log bs=1M count=500 status=progress
```

Уменьшим размер файловой системы до 1 G и затем удалим раздел и создадим раздел с меньшим размером:

```
umount /data2
e2fsck -fy /dev/sdc1
resize2fs /dev/sdc1 1G
fdisk /dev/sdc
d
n
p
1
+1G
w
mount /dev/sdc1 /data2/
```

В результате после пересоздания тома с меньшим размером  имеющиеся на файловой системе данные сохранены.

Итоговое сосотояние:

```
NAME                       MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                          8:0    0   40G  0 disk 
├─sda1                       8:1    0    1M  0 part 
├─sda2                       8:2    0    1G  0 part /boot
└─sda3                       8:3    0   39G  0 part 
  ├─VolGroup00-LogVol00    253:0    0    8G  0 lvm  /
  ├─VolGroup00-LogVol01    253:1    0  1.5G  0 lvm  [SWAP]
  ├─VolGroup00-LogVol_Home 253:2    0    2G  0 lvm  /home
  └─VolGroup00-LogVol_Data 253:8    0    6G  0 lvm  /data
sdb                          8:16   0   10G  0 disk 
sdc                          8:32   0    2G  0 disk 
└─sdc1                       8:33   0    1G  0 part /data2
sdd                          8:48   0    1G  0 disk 
├─vg_var-lv_var_rmeta_0    253:3    0    4M  0 lvm  
│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0   253:4    0  952M  0 lvm  
  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
sde                          8:64   0    1G  0 disk 
├─vg_var-lv_var_rmeta_1    253:5    0    4M  0 lvm  
│ └─vg_var-lv_var          253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1   253:6    0  952M  0 lvm  
  └─vg_var-lv_var          253:7    0  952M  0 lvm  /var


```



#### Перенос каталога /opt на файловую систему BTRFS :

Создадим раздел Btrfs на диске /dev/sdb для дальнейшего размещения здесь каталога /opt. В нашем случае раздел займет все пространство диска 10G:

```
mkfs.btrfs /dev/sdb
```

Можно разместить файловую систему и на нескольких устройствах. Например на физическом устройстве `/dev/sdb` и на логическом томе `/dev/VolGroup00/LogVol_Opt` с метаданными `-m` и данными `-d` в raid1:

```
lvcreate -n LogVol_Opt -L 10G /dev/VolGroup00
mkfs.btrfs -m raid1 -d raid1 /dev/sdb /dev/VolGroup00/LogVol_Opt
```

Временно смонтирует файловую систему в /mnt/ и создадим два подтома (subvolume): opt - для каталога /opt,  snap - для каталога со снапшотами /snapshot. В дальнейшем работать будем уже с подтомами. Это позволит при необходимости вместо тома смонтировать его снимок.

```
mount /dev/sdb /mnt/
btrfs subvolume create /mnt/opt
btrfs subvolume create /mnt/snap
```

Посмотрим информацию о созданных подтома. Они имеют ID, начинающиеся после 256. Корень созданной файловой системы btrfs имеет ID 5:

```
[root@lvm ~]# btrfs subvolume list /mnt/
ID 257 gen 7 top level 5 path opt
ID 258 gen 8 top level 5 path snap
```

Информацию о  файловой системе пожно посмотреть командами:

```
btrfs filesystem show
btrfs filesystem usage /mnt/
btrfs filesystem df /mnt/
```

Перенесем содержимое каталога /opt в подтом opt

```
cp -aR /opt/* /mnt/opt/
rm -rf /opt/*
```

Размонтируем корень больше его для монтирования использовать не будем

```
umount /dev/sdb 
```

Смонтируем подтома opt и snap. Можно включить опцию space_cache , чтобы уменьшить количество операций чтения и записи. Монтировать можно по имени подтома или по его ID

```
mount -o subvol=opt,space_cache /dev/sdb /opt    #либо mount -o subvolid=257 /dev/sdb /opt
mkdir /snapshot
mount -o subvol=snap,space_cache /dev/sdb /snapshot/
```

Правим `/etc/fstab` для автоматического монтирования `/opt` и `/snapshot`:

```
echo "`blkid | grep /dev/sdb | awk '{print $2}'` /opt btrfs defaults,subvol=opt 0 0" >>\ /etc/fstab

echo "`blkid | grep /dev/sdb | awk '{print $2}'` /snapshot btrfs defaults,subvol=snap 0 0" >>\ /etc/fstab
```

Cоздадим файл test.sh размером 7G, сделаем снапшот каталога /opt в каталоге /snapshot и затем удалим созданный файл из /opt:

```
dd if=/dev/zero of=/opt/test.sh bs=1M count=7000 status=progress
btrfs subvolume snapshot /opt /snapshot/
rm /opt/test.sh
```

Результат:

```
[root@lvm ~]# ll /opt/
total 0
drwxr-xr-x. 1 root root 122 Nov 26 19:13 VBoxGuestAdditions-5.2.32

[root@lvm ~]# ll /snapshot/opt/
total 7168000
-rw-r--r--. 1 root root 7340032000 Nov 26 20:10 test.sh
drwxr-xr-x. 1 root root        122 Nov 26 19:13 VBoxGuestAdditions-5.2.32
```

Можно вместо подтома opt смонтировать его снимок, находящийся в /snapshot/opt/

```
umount /opt/
mount -o subvol=snap/opt /dev/sdb /opt
```

