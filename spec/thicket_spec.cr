require "./spec_helper"

describe Thicket do
  it "logs a git repo" do
    temp_dir = File.join(Dir.tempdir, Random::Secure.hex(5))
    FileUtils.mkdir_p(temp_dir)
    FileUtils.cd(temp_dir)

    `git clone https://github.com/taylorthurlow/panda-motd`

    FileUtils.cd(File.join(temp_dir, "panda-motd"))

    Thicket.run

    FileUtils.rm_rf(temp_dir)
  end
end
