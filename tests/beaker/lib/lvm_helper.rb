# Verify if a physical volume, volume group, logical volume, or filesystem resource type is created
#
# ==== Attributes
#
# * +resource_type+ - resorce type, i.e 'physical_volume', 'volume_group', 'logical_volume', 'filesystem',
# *                   'aix_physical_volume', 'aix_volume_group', or 'aix_logical_volume'.
# * +resource_name+ - The name of resource type, i.e '/dev/sdb' for physical volume, vg_1234 for volume group
# * +vg+ - volume group name associated with logical volume (if any)
# * +properties+ - a matching string or regular expression in logical volume properties
# ==== Returns
#
# +nil+
#
# ==== Raises
# assert_match failure message
# ==== Examples
#
# verify_if_created?(agent, 'physical_volume', /dev/sdb', VolumeGroup_123, "Size     7GB")
def verify_if_created?(agent, resource_type, resource_name, vol_group = nil, properties = nil)
  case resource_type
  when 'physical_volume'
    on(agent, 'pvdisplay') do |result|
      assert_match(%r{#{resource_name}}, result.stdout, 'Unexpected error was detected')
    end
  when 'volume_group'
    on(agent, 'vgdisplay') do |result|
      assert_match(%r{#{resource_name}}, result.stdout, 'Unexpected error was detected')
    end
  when 'logical_volume'
    raise ArgumentError, 'Missing volume group that the logical volume is associated with' unless vol_group

    on(agent, "lvdisplay /dev/#{vol_group}/#{resource_name}") do |result|
      assert_match(%r{#{resource_name}}, result.stdout, 'Unexpected error was detected')
      if properties
        assert_match(%r{#{properties}}, result.stdout, 'Unexpected error was detected')
      end
    end
  when 'aix_physical_volume'
    on(agent, "lspv #{resource_name}") do |result|
      assert_match(%r{Physical volume #{resource_name} is not assigned to}, result.stdout, 'Unexpected error was detected')
    end
  when 'aix_volume_group'
    on(agent, 'lsvg') do |result|
      assert_match(%r{#{resource_name}}, result.stdout, 'Unexpected error was detected')
    end
  when 'aix_logical_volume'
    raise ArgumentError, 'Missing volume group that the logical volume is associated with' unless vol_group

    on(agent, "lslv #{resource_name}") do |result|
      assert_match(%r{#{resource_name}}, result.stdout, 'Unexpected error was detected')
      if properties
        assert_match(%r{#{properties}}, result.stdout, 'Unexpected error was detected')
      end
    end
  end
end

# Verify if a filesystem resource type is successfully created
#
# ==== Attributes
#
# * +volume_group+ - resorce type name, i.e 'VolumeGroup_1234'
# * +logical_volume+ - resorce type name, i.e 'LogicalVolume_a2b3'
# * +fromat_type+ - type of the format of the logical volume, i.e 'ext3'
#
# ==== Returns
#
# +nil+
#
# ==== Raises
# assert_match failure message
# ==== Examples
#
# is_correct_format?(agent, VolumeGroup_1234, LogicalVolume_a2b3, ext3)
def is_correct_format?(agent, volume_group, logical_volume, format_type)
  on(agent, "file -sL /dev/#{volume_group}/#{logical_volume}") do |result|
    assert_match(%r{#{format_type}}, result.stdout, 'Unexpected error was detected')
  end
end

# Clean the box after each test, make sure the newly created logical volumes, volume groups,
# and physical volumes are removed at the end of each test to make the server ready for the
# next test case.
#
# ==== Attributes
#
# * +pv+ - physical volume, can be one volume or an array of multiple volumes
# * +vg+ - volume group, can be one group or an array of multiple volume groups
# * +lv+ - logical volume, can be one volume or an array of multiple volumes
# * +aix+ - if the agent is an AIX server.
#
# ==== Returns
#
# +nil+
#
# ==== Raises
# +nil+
# ==== Examples
#
# remove_all(agent, '/dev/sdb', 'VolumeGroup_1234', 'LogicalVolume_fa13')
def remove_all(agent, physical_volume = nil, vol_group = nil, logical_volume = nil, aix = false)
  if aix
    step 'remove aix volume group, physical/logical volume '
    on(agent, "reducevg -d -f #{vol_group} #{physical_volume}")
    on(agent, "rm -rf /dev/#{vol_group} /dev/#{logical_volume}")
  else
    step 'remove logical volume if any:'
    if logical_volume
      if logical_volume.is_a?(Array)
        logical_volume.each do |logical_volume|
          on(agent, "umount /dev/#{vol_group}/#{logical_volume}", acceptable_exit_codes: [0, 1])
          on(agent, "lvremove /dev/#{vol_group}/#{logical_volume} --force")
        end
      else
        # note: in some test cases, for example, the test case 'create_vg_property_logical_volume'
        # the logical volume must be unmount before being able to delete it
        on(agent, "umount /dev/#{vol_group}/#{logical_volume}", acceptable_exit_codes: [0, 1])
        on(agent, "lvremove /dev/#{vol_group}/#{logical_volume} --force")
      end
    end

    step 'remove volume group if any:'
    if vol_group
      if vol_group.is_a?(Array)
        vol_group.each do |volume_group|
          on(agent, "vgremove /dev/#{volume_group}")
        end
      else
        on(agent, "vgremove /dev/#{vol_group}")
      end
    end

    step 'remove logical volume if any:'
    if physical_volume
      if physical_volume.is_a?(Array)
        physical_volume.each do |physical_volume|
          on(agent, "pvremove #{physical_volume}")
        end
      else
        on(agent, "pvremove #{physical_volume}")
      end
    end
  end
end
