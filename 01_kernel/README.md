# Занятие № 1



## Краткое содержание

Версии LInux. Ядро Linux. Функции, виды и версии ядер. Многозадачность. Syscalls. Обновление ядра. Ручная сборка ядра

## Домашнее задание

Обновить ядро в базовой системе.

Цель: Студент получит навыки работы с Git, Vagrant, Packer и публикацией готовых образов в Vagrant Cloud.

В материалах к занятию есть методичка, в которой описана процедура обновления ядра из репозитория. По данной методичке требуется выполнить необходимые действия. Полученный в ходе выполнения ДЗ Vagrantfile должен быть залит в ваш репозиторий. Для проверки ДЗ необходимо прислать ссылку на него.
Для выполнения ДЗ со * и ** вам потребуется сборка ядра и модулей из исходников.

Критерии оценки: Основное ДЗ - в репозитории есть рабочий Vagrantfile с вашим образом.
ДЗ со звездочкой: Ядро собрано из исходников
ДЗ с **: В вашем образе нормально работают VirtualBox Shared Folders

------



## Выполнение

### Работа с Vagrant

- ##### Сборка ядра 5.3.8 из исходников c kernel.org

Для корректной работы  VirtualBox Shared Folders на ядре 5.3.8  в секцию `provision` Vagrantfile включил установку VBoxGuestAdditions_6.0.14

    curl -o /tmp/VBoxGuestAdditions_6.0.14.iso https://download.virtualbox.org/virtualbox/6.0.14/VBoxGuestAdditions_6.0.14.iso
    mount -o loop /tmp/VBoxGuestAdditions_6.0.14.iso /mnt
    /mnt/VBoxLinuxAdditions.run
Vagrantfile находится:

https://github.com/a-dolotov/otus-linux_kernel

На выходе имеем работающую систему, загружамую с новым ядром 5.3.8 по умолчанию и рабочими  VirtualBox Shared Folders

- ##### Обновления ядра из репозитория elrepo.org

Вслучае, если ядро не собирал из сходников, а обновлял из репозитория elrepo.org,

    rpm --import https://www.elrepo.org/RPM-GPG-KEY-elrepo.org
    yum install -y https://www.elrepo.org/elrepo-release-7.0-4.el7.elrepo.noarch.rpm
    yum --enablerepo elrepo-kernel install kernel-ml -y 
то  VirtualBox Shared Folders на новом ядре не заработали:

> No package kernel-devel-5.3.8-1.el7.elrepo.x86_64 available

Это проблему не решил



### Работа с Packer

- **Сборка ядра 5.3.8 из исходников c kernel.org**

Все тоже самое, что и с Vagrant. за исключением того, что если созданный образ сразу загрузить с ядром 5.3.8. то VirtualBox Shared Folders не работают.

Если же при создании образа оставить ядро по умолчанию 3.10 и после загрузиться сначала с него, а потом уже загрузиться с ядром 5.3.8, то VirtualBox Shared Folders работают. Поэтому в приложенном образе оставил по умолчанию загрузку ядра 3.10

Файл образа находится:

https://app.vagrantup.com/a-dolotov/boxes/centos-7-5

