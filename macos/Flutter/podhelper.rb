require 'fileutils'

def __flutter_root_from_xcconfig
  xc = File.expand_path(File.join(__dir__, 'ephemeral', 'Flutter-Generated.xcconfig'))
  raise "Missing #{xc}. Run `flutter pub get` first." unless File.exist?(xc)
  File.foreach(xc) do |line|
    return line.split('FLUTTER_ROOT=')[1].strip if line.include?('FLUTTER_ROOT=')
  end
  raise "FLUTTER_ROOT not found in #{xc}"
end

flutter_root = __flutter_root_from_xcconfig

candidates = [
  File.expand_path(File.join(flutter_root, 'packages', 'flutter_tools', 'bin', 'podhelper_macos.rb')),
  File.expand_path(File.join(flutter_root, 'packages', 'flutter_tools', 'bin', 'podhelper.rb'))
]
found = candidates.find { |p| File.exist?(p) }
raise "Flutter podhelper not found. Tried:\n#{candidates.join("\n")}" unless found

require found
