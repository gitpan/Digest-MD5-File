package Digest::MD5::File;

use strict;
use warnings;
use Carp;
use Digest::MD5;
use Encode;
use LWP::UserAgent;

require Exporter;
our @ISA = qw(Exporter Digest::MD5);
our @EXPORT_OK = qw(file_md5 file_md5_hex file_md5_base64 url_md5 url_md5_hex url_md5_base64);

our $BINMODE = 1;
our $UTF8 = 0;
our $NOFATALS = 0;

sub import {
   my $me = shift;
   my %imp;
   @imp{ @_ } = ();
   for(@EXPORT_OK) {
      delete $imp{$_} if exists($imp{$_});
   }
   $BINMODE = 0 if exists $imp{-nobin};
   $UTF8 = 1 if exists $imp{-utf8};
   $NOFATALS = 1 if exists $imp{-nofatals};
   for(keys %imp) { 
      s/^-//;
      $imp{$_}='' unless $_ =~ m/^(no)?(bin|utf8|fatals)$/;
      push @EXPORT_OK, $_ unless $_ =~ m/^(no)?(bin|utf8|fatals)$/;
      delete $imp{"-$_"} if exists $imp{"-$_"};
   }
   $me->export_to_level(2, $me, grep(!/^-/, @_));
   Digest::MD5->import(keys %imp);
}

our $VERSION = '0.02';

my $getfh = sub {
   my $file = shift;
   croak "$file: Does not exist" if !-e $file && !$NOFATALS;
   croak "$file: Is a directory" if -d $file && !$NOFATALS;
   if(-e $file && !-d $file) {
      open my ($fh), $file or return;
      binmode $fh if $BINMODE;
      return $fh;
   } else { return undef; }
};

my $utf8fh = sub {
   my @utf8;
   my $fh = shift;
   for(<$fh>) { push @utf8, Encode::encode_utf8($_) }
   return @utf8;
};

my $getur = sub {
   my $res = LWP::UserAgent->new->get(shift());
   return $res->is_success ? $res->content : undef;
};

sub file_md5 {
   my $fh = $getfh->(shift()) or return; 
   my ($bn,$ut) = @_;
   local $BINMODE = $bn if defined $bn;
   local $UTF8 = $ut if defined $ut;
   return Digest::MD5::md5(<$fh>) if !$UTF8;
   return Digest::MD5::md5($utf8fh->($fh)); 
}

sub file_md5_hex {
   my $fh = $getfh->(shift()) or return;
   my ($bn,$ut) = @_;
   local $BINMODE = $bn if defined $bn;
   local $UTF8 = $ut if defined $ut;
   return Digest::MD5::md5_hex(<$fh>) if !$UTF8;
   return Digest::MD5::md5_hex($utf8fh->($fh));
} 

sub file_md5_base64 {
   my $fh = $getfh->(shift()) or return;
   my ($bn,$ut) = @_;
   local $BINMODE = $bn if defined $bn;
   local $UTF8 = $ut if defined $ut;
   return Digest::MD5::md5_base64(<$fh>) if !$UTF8;
   return Digest::MD5::md5_base64($utf8fh->($fh));
}

sub url_md5 {
   my $cn = $getur->(shift()) or return;
   my ($ut) = shift;
   local $UTF8 = $ut if defined $ut;
   return Digest::MD5::md5($cn) if !$UTF8;
   return Digest::MD5::md5(Encode::encode_utf8($cn));
}

sub url_md5_hex {
   my $cn = $getur->(shift()) or return;
   my ($ut) = shift;
   local $UTF8 = $ut if defined $ut;
   return Digest::MD5::md5_hex($cn) if !$UTF8;
   return Digest::MD5::md5_hex(Encode::encode_utf8($cn));
}

sub url_md5_base64 { 
   my $cn = $getur->(shift()) or return;
   my ($ut) = shift;
   local $UTF8 = $ut if defined $ut;
   return Digest::MD5::md5_base64($cn) if !$UTF8;
   return Digest::MD5::md5_base64(Encode::encode_utf8($cn));
}

sub Digest::MD5::addpath {
   my $md5 = shift;
   my ($fl,$bn,$ut) = @_;
   local $BINMODE = $bn if defined $bn;
   local $UTF8 = $ut if defined $ut;
   if(ref $fl eq 'ARRAY') {
      for(@{ $fl }) {
         $md5->addpath($_,$bn,$ut);
      }
   } else {
      my $fh = $getfh->($fl) or return;
      while(<$fh>) {
         !$UTF8 ? $md5->add($_) : $md5->add(Encode::encode_utf8($_));
      }
   }
   1;
}

sub Digest::MD5::addurl {
   my $md5 = shift;
   my $cn = $getur->(shift()) or return;
   my $ut = shift;
   local $UTF8 = $ut if defined $ut;
   !$UTF8 ? $md5->add($cn) : $md5->add(Encode::encode_utf8($cn));
}

1;

__END__

=head1 NAME

Digest::MD5::File - Perl extension for getting MD5 sums for files and urls. 

=head1 SYNOPSIS

  use Digest::MD5::File qw(file_md5 file_md5_hex file_md5_base64 url_md5 url_md5_hex url_md5_base64);

  my $md5 = Digest::Md5->new;
  $md5->addpath("/path/to/file");
  my $digest = $md5->hexdigest;

  my $digest = file_md5($file);
  my $digest = file_md5_hex($file);
  my $digest = file_md5_base64($file);

  my $md5 = Digest::Md5->new;
  $md5->addurl('http://www.tmbg.com/tour.html');
  my $digest = $md5->hexdigest;

  my $digest = url_md5($url);
  my $digest = url_md5_hex($url);
  my $digest = url_md5_base64($url);
  

=head1 DESCRIPTION

  Get MD5 sums for files of a given path or content of a given url.

=head1 EXPORT

None by default.
You can export any file_* or url_* function and anything L<Digest::MD5> can export.

   use Digest::MD5::File qw(md5 md5_hex md5_base64); # 3 Digest::MD5 functions
   print md5_hex('abc123'), "\n";
   print md5_base64('abc123'), "\n";

=head1 OBJECT METHODS

=head2 addpath()

  my $md5 = Digest::Md5->new;
  $md5->addpath("/path/to/file");

or you can add multiple files by specifying an array ref of files:

  $md5->addpath(\@files);

=head2 addurl()

  my $md5 = Digest::Md5->new;
  $md5->addurl('http://www.tmbg.com/tour.html') or die "They Must Be not on tour";

=head1 file_* functions

Get the digest in variouse formats of $file.
If file does not exist or is a directory it croaks (See NOFATALS for more info)

  my $digest = file_md5($file);
  my $digest = file_md5_hex($file);
  my $digest = file_md5_base64($file);

=head1 url_* functions

Get the digest in various formats of the content at $url (Including, if $url points to directory, the directory listing content).
Returns undef if url fails (IE if L<LWP::UserAgent>'s $res->is_success is false)

  my $digest = url_md5($url) or warn "$url failed"; 
  my $digest = url_md5_hex($url) or warn "$url failed";
  my $digest = url_md5_base64($url) or warn "$url failed";

=head1 SPECIAL SETTINGS

=head2 BINMODE

By default files are opened in binmode. If you do not want to do this you can unset it a variety of ways:

   use Digest::MD5::File qw(-nobin);

or

   $Digest::MD5::File::BINMODE = 0;

or at the function/method level by specifying its value as the second argument:

   $md5->addpath($file,0);

   my $digest = file_md5_hex($file,0);

=head2 UTF8

In some cases you may want to have your data utf8 encoded, you can do this the following ways:

   use Digest::MD5::File qw(-utf8);

or

   $Digest::MD5::File::UTF8 = 1;

or at the function/method level by specifying its value as the third argument for files and second for urls:

   $md5->addpath($file,$binmode,1);

   my $digest = file_md5_hex($file,$binmode,1);

   $md5->addurl($url,1);

   url_md5_hex($url,1);

It use's L<Encode>'s encode_utf8() function to do the encoding.

=head2 NOFATALS

Instead of croaking it will return undef if you set NOFATALS to true.

You can do this two ways:

   $Digest::MD5::File::NOFATALS = 1;

or the -nofatals flag:

   use Digest::MD5::File qw(-nofatals);

   my $digest = file_md5_hex($file) or die "$file failed";

$! is not set so its not really helpful if you die(). 

=head1 SEE ALSO

L<Digest::MD5>, L<Encode>, L<LWP::UserAgent>

=head1 AUTHOR

Daniel Muey, L<http://drmuey.com/cpan_contact.pl>

=head1 COPYRIGHT AND LICENSE

Copyright 2005 by Daniel Muey

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
