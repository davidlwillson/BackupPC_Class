# Introduction to BackupPC for Software Freedom School

### Introduction
[BackupPC](http://backuppc.sourceforge.net/) is a high-performance, enterprise-grade system for backing up Linux, WinXX and Mac OS X PCs and laptops to a server's disk. BackupPC is highly configurable and easy to install and maintain.

This class is a simple class on how to setup BackupPC to protect your data stored on Linux computers with speed and security. It should work just fine for Mac OSX as well. Windows is a whole different animal

### We will cover:
* What BackupPC is and what it is good for as well as what it is not and does not do well
* Installation and configuration on Ubuntu, and optionally, Centos
* The different methods of backup that BackupPC uses and when to use them
* Offsite backups
* Restoring those files because no backup exists unless it's tested
* How to handle open files such as databases and filesystems that might change during the backup
* How to get BackupPC to tell you what's going on, or if it needs help
* How to securely backup Linux computers, and protect the data that you have backed up
* How to protect your computers from your BackupPC server
* Additional resources to check out such as Puppet and Chef automated deployments

And of course, we're going to have examples, complete with common errors and how to fix them. You will get to see a running live installation, maybe even two.

### System Requirements
* A computer with an installed and running Virtualbox. The host computer OS doesn't much matter.
* About 2-3 GB of available ram for running virtual machines. More is always better.
* About 30 GB free disk space. More is better, and couldn't hurt. The virtual machines are small, but we are teaching backups, so expect some space growth.
* A free USB 2.0 or better port to receive images for virtual machines.
