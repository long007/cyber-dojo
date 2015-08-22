#!/usr/bin/env ../test_wrapper.sh lib

require_relative 'lib_test_base'

class DockerVolumeMountRunnerTests < LibTestBase

  def setup
    super
    set_disk_class_name     'DiskStub'
    set_git_class_name      'GitSpy'
    set_one_self_class_name 'OneSelfDummy'
    @bash = BashStub.new
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'when docker is not installed, initialize() raises RuntimeError' do
    stub_docker_not_installed
    assert_raises(RuntimeError) { make_docker_runner }
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'when docker is installed, bash commands run in initialize() do not sudo' do
    stub_docker_installed
    make_docker_runner
    assert @bash.spied[0].start_with?('docker info'), 'docker info'
    assert @bash.spied[1].start_with?('docker images'), 'docker images'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'when docker is installed, image_names determines runnability' do
    stub_docker_installed
    docker = make_docker_runner    
    expected_image_names =
    [
      "cyberdojo/python-3.3.5_pytest",
      "cyberdojo/rust-1.0.0_test"
    ]
    c_assert = languages['C-assert']
    python_py_test = languages['Python-py.test']

    assert_equal expected_image_names, docker.image_names        
    refute docker.runnable?(c_assert);
    assert docker.runnable?(python_py_test);
  end
    
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'started(avatar) is a no-op' do
    stub_docker_installed
    docker = make_docker_runner
    before = @bash.spied.clone
    docker.started(nil)
    after = @bash.spied.clone
    assert_equal before, after
  end
    
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'pre_test(avatar) is a no-op' do
    stub_docker_installed
    docker = make_docker_runner
    before = @bash.spied.clone
    docker.pre_test(nil)
    after = @bash.spied.clone
    assert_equal before,after
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'run() completes and does not timeout' do
    stub_docker_installed
    docker = make_docker_runner
    @lion = make_kata.start_avatar(['lion'])
    stub_docker_run(completes)
    output = docker.run(@lion.sandbox, cyber_dojo_cmd, max_seconds)
    assert_equal 'blah',output, 'output'
    assert_bash_commands_spied
  end    
  
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  test 'run() times out' do
    stub_docker_installed
    docker = make_docker_runner
    @lion = make_kata.start_avatar(['lion'])
    stub_docker_run(fatal_error(kill))
    output = docker.run(@lion.sandbox, cyber_dojo_cmd, max_seconds)
    assert output.start_with?("Unable to complete the tests in #{max_seconds} seconds."), 'Unable'
    assert_bash_commands_spied
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def make_docker_runner
    DockerVolumeMountRunner.new(@bash,cid_filename)
  end
  
  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    
  def assert_bash_commands_spied
    spied = @bash.spied
    assert_equal "rm -f #{cid_filename}", spied[2], 'remove cidfile'
    assert_equal exact_docker_run_cmd,    spied[3], 'main docker run command'
    assert_equal "cat #{cid_filename}",   spied[4], 'get pid from cidfile'
    assert_equal "docker stop #{pid}",    spied[5], 'docker stop pid'
    assert_equal "docker rm #{pid}",      spied[6], 'docker rm pid'
  end

  # - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  def exact_docker_run_cmd
    language = @lion.kata.language
    language_path = language.path
    language_volume_mount = language_path + ':' + language_path + ":ro"
    kata_volume_mount = @lion.sandbox.path + ":/sandbox:rw"

    command = "timeout --signal=#{kill} #{max_seconds}s #{cyber_dojo_cmd} 2>&1"

    "timeout --signal=#{kill} #{max_seconds+5}s" +
      ' docker run' +
        ' --user=www-data' +
        " --cidfile=#{quoted(cid_filename)}" +
        ' --net=none' +
        " -v #{quoted(language_volume_mount)}" +
        " -v #{quoted(kata_volume_mount)}" +
        ' -w /sandbox' +
        " #{language.image_name}" +
        " /bin/bash -c #{quoted(command)} 2>&1"
  end

end
