# My Gentoo overlay

:us: :gb:

This overlay is both a repository for some applications and an incubator for others. I try to maintain all applications up to date. If this is not the case, please feel free to file a bug, I will try to update as soon as possible.

Note that some of the applications are here as in incubator. It means that:

* An issue should be opened in [Gentoo's Bugzilla](https://bugs.gentoo.org/).
* A pull request may have been submitted to the [official repository](https://github.com/gentoo/gentoo).
* The application can be removed from this overlay when accepted in the official tree.

These applications are clearly indicated in the description below. Concerning other applications, if they are useful for me, they could also be useful for others. Therefore, they also may one day become incubated.

:fr:

Cette surcouche à l'arbre officiel de _Gentoo Portage_ est à la fois un dépôt pour certaines applications et un incubateur pour d'autres. J'essaie de maintenir toutes les applications à jour. Si ce n'est pas le cas, n'hésitez pas à soumettre un incident, j'essaierai de mettre à jour dès que possible.

Notez que certaines applications sont ici en incubation. Cela signifie que :

* un incident a dû être ouvert dans le [Bugzilla Gentoo](https://bugs.gentoo.org/) ;
* une _pull request_ a potentiellement été soumise sur le [dépôt officiel](https://github.com/gentoo/gentoo) ;
* l'application pourra être retirée de ce dépôt une fois acceptée dans l'arbre officiel.

Ces applications sont clairement indiquées dans la description ci-dessous. En ce qui concerne les autres applications, puisqu'elles me sont utiles, elles sont potentiellement utiles à d'autres. De ce fait, elle peuvent également un jour passer en incubation.

# Usage

:us: :gb:

You can either:

* use [layman](https://wiki.gentoo.org/wiki/Layman#Missing_repository.xml_file), but you will have to manually create the `xml` file;
* use [eselect](https://wiki.gentoo.org/wiki/Eselect/Repository) typing the below command;
* or manually create a file named `/etc/portage/repos.conf/sveyret.conf` with the content below.

:fr:

Vous pouvez soit :

* utiliser [layman](https://wiki.gentoo.org/wiki/Layman#Missing_repository.xml_file), mais vous devrez créer le fichier `xml` à la main ;
* utiliser [eselect](https://wiki.gentoo.org/wiki/Eselect/Repository) en tapant la commande ci-dessous ;
* ou encore créer un fichier `/etc/portage/repos.conf/sveyret.conf` à la main avec le contenu ci-dessous.

**eselect**:

    eselect repository add sveyret git https://github.com/sveyret/sveyret-gentoo.git

**/etc/portage/repos.conf/sveyret.conf**:

    [sveyret]
    priority = 50
    location = /var/db/repos/sveyret
    sync-type = git
    sync-uri = https://github.com/sveyret/sveyret-gentoo.git
    auto-sync = Yes

# Applications

## app-editors/pluma-grammalecte

:ticket: pluma-grammalecte

:speech_balloon: Grammalecte plugin for pluma editor.

:link: https://github.com/sveyret/pluma-grammalecte/

## app-shells/magicd

:ticket: MagiCd

:speech_balloon: MagiCd, makes cd become magic!

:link: https://github.com/sveyret/magicd/

## app-text/grammalecte-bin

:ticket: Grammalecte

:speech_balloon: French grammar checker (binary distribution).

:link: http://grammalecte.net/

## dev-db/squirrel-sql

:ticket: SQuirreL SQL

:speech_balloon: Universal SQL Client.

:link: http://squirrel-sql.sourceforge.net/

## dev-util/codelite

:construction_worker: **Incubator**: [bug #51498](https://bugs.gentoo.org/show_bug.cgi?id=551498)

:ticket: CodeLite IDE

:speech_balloon: A Free, open source, cross platform C,C++,PHP and Node.js IDE.

:link: http://codelite.org/

## net-p2p/duniter

:ticket: Duniter

:speech_balloon: Crypto-currency software to manage libre currency.

:link: https://duniter.org/

## net-p2p/duniter-desktop-bin

:ticket: Duniter Desktop (binary)

:speech_balloon: Crypto-currency software to manage libre currency.

:link: https://duniter.org/

## sys-apps/misybag-baselayout

:ticket: MisybaG base layout

:speech_balloon: The base layout for MisybaG distribution.

:link: https://github.com/sveyret/misybag-baselayout/

## sys-boot/refind

:feet: Now in official Gentoo portage tree.

## sys-boot/udk

:feet: Now in official Gentoo portage tree.

## sys-kernel/kema

:ticket: kema

:speech_balloon: The Gentoo kernel manager.

:link: https://github.com/sveyret/kema/

