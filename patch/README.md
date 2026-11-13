## 1. Prepare dependencies

```
sudo dnf install rpm-build rpmdevtools dnf-plugins-core
sudo dnf builddep openssh
```

Get the Fedora source package. Run this as a normal user, not root:

```
rpmdev-setuptree                      # creates ~/rpmbuild/{SOURCES,SPECS,...}
cd ~ && dnf download --source openssh
rpm -ivh openssh-*.src.rpm            # unpacks into ~/rpmbuild
```

## 2. Put the patch into SOURCES

```
cp 1001-sftp-server-directory-first.patch ~/rpmbuild/SOURCES/
```

Check that no other patch already uses the number 1001:

```
ls ~/rpmbuild/SOURCES/*.patch | tail
```

## 3. Add the patch to the spec file

Edit `~/rpmbuild/SPECS/openssh.spec`. See how it lists patches:

```
grep -nE '^Patch[0-9]+|^%patchlist|^%autosetup|^%patch' ~/rpmbuild/SPECS/openssh.spec
```

- **If the spec uses a `%patchlist` section**, add this as the **last line**
  of the list:
  ```
  1001-sftp-server-directory-first.patch
  ```
- **If it uses `PatchNNNN:` tags**, add a tag and, if the spec applies
  patches with explicit `%patch` lines, the matching line as well:
  ```
  Patch1001: 1001-sftp-server-directory-first.patch
  ```

Keep it **last**, so it applies on top of all of Fedora's own patches.

Verify that the source prepares and the patch applies (nothing is compiled):

```
rpmbuild -bp ~/rpmbuild/SPECS/openssh.spec
```

The output must show `1001-sftp-server-directory-first.patch` being applied
by `patch -p1 -s --fuzz=0` and end without errors. Fuzz is not allowed, so a
patch that no longer matches (e.g. after a Fedora update) fails loudly rather
than silently misapplying. Confirm the code is in the tree:

```
grep -n "rest_of_files" ~/rpmbuild/BUILD/openssh-*-build/openssh-*/sftp-server.c
```

## 4. Build

Compile only, with Fedora's own build flags (hardening, PIE, RELRO):

```
rpmbuild -bc ~/rpmbuild/SPECS/openssh.spec
find ~/rpmbuild/BUILD -name sftp-server -type f -perm -u+x
```

If `find` returns several paths, use the one in the main source tree
(`openssh-<version>/sftp-server`). Optionally strip it to match the size of
the stock binary:

```
strip /path/to/sftp-server
```

You can add `--nocheck` if the test phase is slow or unwanted.

Optional: build real RPM packages instead of replacing a single binary:

```
# bump Release in the spec first, e.g.  Release: 16%{?dist}.dirs1
rpmbuild -bb ~/rpmbuild/SPECS/openssh.spec
```

Installing a modified `openssh-server` RPM means a later Fedora update will
replace it, unless you use `dnf versionlock` (which also holds back security
fixes until you rebuild).
