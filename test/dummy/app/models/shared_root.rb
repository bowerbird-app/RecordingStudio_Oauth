class SharedRoot < ApplicationRecord
  recording_studio_recordable label: "Messages", root: true, shared: true
end
