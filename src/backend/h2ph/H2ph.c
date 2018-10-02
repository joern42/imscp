/* i-MSCP - internet Multi Server Control Panel
 Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>

 This library is free software; you can redistribute it and/or
 modify it under the terms of the GNU Lesser General Public
 License as published by the Free Software Foundation; either
 version 2.1 of the License, or (at your option) any later version.

 This library is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 Lesser General Public License for more details.

 You should have received a copy of the GNU Lesser General Public
 License along with this library; if not, write to the Free Software
 Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA */

/* Generate the iMSCP::H2ph package for SYSCALL(2) and IOCTL(2) system calls */

#include <stdio.h>

int main( void ) {
  printf(
  "# i-MSCP - internet Multi Server Control Panel\n"
  "# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>\n"
  "# \n"
  "# This library is free software; you can redistribute it and/or\n"
  "# modify it under the terms of the GNU Lesser General Public\n"
  "# License as published by the Free Software Foundation; either\n"
  "# version 2.1 of the License, or (at your option) any later version.\n"
  "# \n"
  "# This library is distributed in the hope that it will be useful,\n"
  "# but WITHOUT ANY WARRANTY; without even the implied warranty of\n"
  "# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU\n"
  "# Lesser General Public License for more details.\n"
  "# \n"
  "# You should have received a copy of the GNU Lesser General Public\n"
  "# License along with this library; if not, write to the Free Software\n"
  "# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA\n"
  "\n"
  "package iMSCP::H2ph;\n"
  "\n"
  "use strict;\n"
  "use warnings;\n"
  "\n"
  "{\n"
  "    # Loads the required perl header files.\n"
  "    no warnings 'portable';\n"
  "    require 'syscall.ph';\n"
  "    require 'linux/fs.ph';\n"
  "    require 'sys/mount.ph';\n"
  "}\n"
  "\n"
  /* We have to build the %sizeof hash by ourself as the H2PH(1) converter
    doesn't do that for us. We provide only Basic C types.
    see https://en.wikipedia.org/wiki/C_data_types
    See https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=190887
  */
  "# We need build the %%sizeof hash as the H2PH(1) converter\n"
  "# doesn't do that for us.\n"
  "# See https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=190887\n"

#ifdef DEBUG
  "\n"
  "{\n"
  "    package iMSCP::H2ph::HASH;\n"
  "    require Tie::Hash;\n"
  "    our @ISA = qw/ Tie::StdHash /;\n\n"
  "    sub FETCH {\n"
  "        my $context = sprintf qq[in %%s file %%s at line %%s.], caller;\n"
  "        warn qq[No sizeof for C type '$_[1]' $context\\n] unless exists $_[0]{$_[1]};\n"
  "        return $_[0]{$_[1]};\n"
  "    }\n"
  "}\n"
  "\n"
  "tie our %%sizeof, 'iMSCP::H2ph::HASH';\n"
  "\n"
  "%%sizeof = (\n");
#else
  "our %%sizeof = (\n");
#endif

  /* char */
  printf("    char                     => 0x%lx,\n", sizeof(char));
  printf("    'signed char'            => 0x%lx,\n", sizeof(signed char));
  printf("    'unsigned char'          => 0x%lx,\n", sizeof(unsigned char));
  printf("    'char unsigned'          => 0x%lx,\n", sizeof(char unsigned));
  /* integer */
  printf("     short                   => 0x%lx,\n", sizeof(short));
  printf("    'short int'              => 0x%lx,\n", sizeof(short int));
  printf("    'signed short'           => 0x%lx,\n", sizeof(signed short));
  printf("    'signed short int'       => 0x%lx,\n", sizeof(signed short int));
  printf("    'unsigned short'         => 0x%lx,\n", sizeof(unsigned short));
  printf("    'short unsigned'         => 0x%lx,\n", sizeof(short unsigned));
  printf("    'unsigned short int'     => 0x%lx,\n", sizeof(unsigned short int));
  printf("    'short unsigned int'     => 0x%lx,\n", sizeof(short unsigned int));
  printf("    int                      => 0x%lx,\n", sizeof(int));
  printf("     signed                  => 0x%lx,\n", sizeof(signed));
  printf("    'signed int'             => 0x%lx,\n", sizeof(signed int));
  printf("     long                    => 0x%lx,\n", sizeof(long));
  printf("    'long int'               => 0x%lx,\n", sizeof(long int));
  printf("    'signed long'            => 0x%lx,\n", sizeof(signed long));
  printf("    'signed long int'        => 0x%lx,\n", sizeof(signed long int));
  printf("    'unsigned long'          => 0x%lx,\n", sizeof(unsigned long));
  printf("    'long unsigned'          => 0x%lx,\n", sizeof(long unsigned));
  printf("    'unsigned long int'      => 0x%lx,\n", sizeof(unsigned long int));
  printf("    'long unsigned int'      => 0x%lx,\n", sizeof(long unsigned int));
  /* ISO C90 does not support ‘long long’ C type */
  printf("    'long long'              => 0x%lx,\n", sizeof(long long));
  printf("    'long long int'          => 0x%lx,\n", sizeof(long long int));
  printf("    'signed long long'       => 0x%lx,\n", sizeof(signed long long));
  printf("    'signed long long int'   => 0x%lx,\n", sizeof(signed long long int));
  printf("    'unsigned long long'     => 0x%lx,\n", sizeof(unsigned long long));
  printf("    'long long unsigned'     => 0x%lx,\n", sizeof(long long unsigned));
  printf("    'unsigned long long int' => 0x%lx,\n", sizeof(unsigned long long int));
  printf("    'long long unsigned int' => 0x%lx,\n", sizeof(long long unsigned int));
  /* Real floating-point */
  printf("    float                    => 0x%lx,\n", sizeof(float));
  printf("    double                   => 0x%lx,\n", sizeof(double));
  printf("    'long double'            => 0x%lx,\n", sizeof(long double));
  /* size_t typedef */
  printf("    size_t                   => 0x%lx\n",  sizeof(size_t));
  printf(");\n\n1;\n__END__\n");

  return 0;
}
