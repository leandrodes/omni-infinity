require 'rails_helper'

RSpec.describe AssignmentPolicy do
  let(:account) { create(:account) }

  describe 'enum values' do
    let(:assignment_policy) { create(:assignment_policy, account: account) }

    describe 'assignment_order' do
      it 'can be set to balanced and priority' do
        assignment_policy.update!(assignment_order: :balanced)
        expect(assignment_policy.balanced?).to be true

        assignment_policy.update!(assignment_order: :priority)
        expect(assignment_policy.priority?).to be true
      end
    end
  end
end
