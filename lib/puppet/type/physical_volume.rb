# frozen_string_literal: true

require 'pathname'

Puppet::Type.newtype(:physical_volume) do
  ensurable

  newparam(:name) do
    isnamevar
    validate do |value|
      unless Pathname.new(value).absolute?
        raise ArgumentError, 'Physical Volume names must be fully qualified'
      end
    end
  end

  newparam(:unless_vg) do
    desc "Do not do anything if the VG already exists.  The value should be the
              name of the volume group to check for."
    validate do |value|
      unless %r{^[0-9A-Z]}i.match?(value)
        raise ArgumentError, "#{value} is not a valid volume group name"
      end
    end
  end

  newparam(:force) do
    desc 'Force the creation without any confirmation.'
    defaultto :false
    newvalues(:true, :false)
  end
end
