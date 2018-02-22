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

#include "stdio.h"

int main(int argc, char **argv) {

  printf("# i-MSCP - internet Multi Server Control Panel\n");
  printf("# Copyright (C) 2010-2018 Laurent Declercq <l.declercq@nuxwin.com>\n");
  printf("# \n");
  printf("# This library is free software; you can redistribute it and/or\n");
  printf("# modify it under the terms of the GNU Lesser General Public\n");
  printf("# License as published by the Free Software Foundation; either\n");
  printf("# version 2.1 of the License, or (at your option) any later version.\n");
  printf("# \n");
  printf("# This library is distributed in the hope that it will be useful,\n");
  printf("# but WITHOUT ANY WARRANTY; without even the implied warranty of\n");
  printf("# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU\n");
  printf("# Lesser General Public License for more details.\n");
  printf("# \n");
  printf("# You should have received a copy of the GNU Lesser General Public\n");
  printf("# License along with this library; if not, write to the Free Software\n");
  printf("# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA\n\n");
  printf("package iMSCP::H2ph;\n\n");
  printf("use File::Basename;\n\n");
  printf("BEGIN {\n");
  printf("    # We do not want keep track of the following\n");
  printf("    local %%INC;\n");
  printf("    local @INC = @INC;\n");
  printf("    push @INC, \"@{[ dirname __FILE__]}/../h2ph/inc\";\n");
  printf("    no warnings 'portable';\n");
  printf("    require 'sys/syscall.ph';\n");
  printf("    require 'linux/fs.ph';\n");
  printf("}\n\n");
  printf("our %%sizeof;\n\n");

#if DEBUG

  printf("{\n");
  printf("    package iMSCP::H2ph::HASH;\n");
  printf("    require Tie::Hash;\n");
  printf("    our @ISA = qw/ Tie::StdHash /;\n\n");
  printf("    sub FETCH {\n");
  printf("        my $context = sprintf qq[in %%s file %%s at line %%s.], caller;\n");
  printf("        warn qq[No sizeof for C type '$_[1]' $context\\n] unless exists $_[0]{$_[1]};\n");
  printf("        return $_[0]{$_[1]};\n");
  printf("    }\n");
  printf("}\n\n");
  printf("tie %%sizeof, 'iMSCP::H2ph::HASH';\n\n");

#endif

  /* We have to build the %sizeof hash by ourself as the H2PH(1) program
    doesn't do that for us. We provide only Basic C types.
    see https://en.wikipedia.org/wiki/C_data_types
    See: https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=190887
    TODO: Build %sizeof hash by extracting C types from various *.ph files
  */
  printf("# See https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=190887\n");
  printf("%%sizeof = (\n");
  /* char */
  printf("    char                     => 0x%lx,\n", sizeof(char));
  printf("    'signed char'            => 0x%lx,\n", sizeof(signed char));
  printf("    'unsigned char'          => 0x%lx,\n", sizeof(unsigned char));
  /* interger */
  printf("     short                   => 0x%lx,\n", sizeof(short));
  printf("    'short int'              => 0x%lx,\n", sizeof(short int));
  printf("    'signed short'           => 0x%lx,\n", sizeof(signed short));
  printf("    'signed short int'       => 0x%lx,\n", sizeof(signed short int));
  printf("    'unsigned short'         => 0x%lx,\n", sizeof(unsigned short));
  printf("    'unsigned short int'     => 0x%lx,\n", sizeof(unsigned short int));
  printf("    'short unsigned int'     => 0x%lx,\n", sizeof(unsigned short int));
  printf("    int                      => 0x%lx,\n", sizeof(int));
  printf("     signed                  => 0x%lx,\n", sizeof(signed));
  printf("    'signed int'             => 0x%lx,\n", sizeof(signed int));
  printf("     long                    => 0x%lx,\n", sizeof(long));
  printf("    'long int'               => 0x%lx,\n", sizeof(long int));
  printf("    'signed long'            => 0x%lx,\n", sizeof(signed long));
  printf("    'signed long int'        => 0x%lx,\n", sizeof(signed long int));
  printf("    'unsigned long'          => 0x%lx,\n", sizeof(unsigned long));
  printf("    'unsigned long int'      => 0x%lx,\n", sizeof(unsigned long int));
  printf("    'long unsigned int'      => 0x%lx,\n", sizeof(long unsigned int));
  /* ISO C90 does not support ‘long long’ C type */
  /*printf("    'long long'              => 0x%lx,\n", sizeof(long long));
  printf("    'long long int'          => 0x%lx,\n", sizeof(long long int));
  printf("    'signed long long'       => 0x%lx,\n", sizeof(signed long long));
  printf("    'signed long long int'   => 0x%lx,\n", sizeof(signed long long int));
  printf("    'unsigned long long'     => 0x%lx,\n", sizeof(unsigned long long));
  printf("    'unsigned long long int' => 0x%lx,\n", sizeof(unsigned long long int));
  */
  /* Real floating-point */
  printf("    float                    => 0x%lx,\n", sizeof(float));
  printf("    double                   => 0x%lx,\n", sizeof(double));
  printf("    'long double'            => 0x%lx,\n", sizeof(long double));
  /* size_t typedef */
  printf("    size_t                   => 0x%lx\n",  sizeof(size_t));
  printf(");\n\n1;\n__END__\n");

  return 0;
}
