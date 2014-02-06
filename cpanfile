requires "Carp" => "0";
requires "Exporter" => "0";
requires "File::Spec" => "0";
requires "File::Temp" => "0";
requires "IO::Handle" => "0";
requires "Scalar::Util" => "0";
requires "perl" => "5.006";
requires "strict" => "0";
requires "warnings" => "0";

on 'test' => sub {
  requires "ExtUtils::MakeMaker" => "0";
  requires "File::Spec::Functions" => "0";
  requires "IO::File" => "0";
  requires "List::Util" => "0";
  requires "Test::More" => "0.62";
  requires "lib" => "0";
  requires "version" => "0";
};

on 'test' => sub {
  recommends "CPAN::Meta" => "0";
  recommends "CPAN::Meta::Requirements" => "2.120900";
  recommends "Inline" => "0.50";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "6.17";
};

on 'develop' => sub {
  requires "Dist::Zilla" => "5.012";
  requires "Dist::Zilla::Plugin::OSPrereqs" => "0";
  requires "Dist::Zilla::Plugin::Prereqs" => "0";
  requires "Dist::Zilla::Plugin::RemovePrereqs" => "0";
  requires "Dist::Zilla::PluginBundle::DAGOLDEN" => "0.060";
  requires "File::Spec" => "0";
  requires "File::Temp" => "0";
  requires "IO::Handle" => "0";
  requires "IPC::Open3" => "0";
  requires "Pod::Coverage::TrustPod" => "0";
  requires "Test::CPAN::Meta" => "0";
  requires "Test::More" => "0";
  requires "Test::Pod" => "1.41";
  requires "Test::Pod::Coverage" => "1.08";
};
