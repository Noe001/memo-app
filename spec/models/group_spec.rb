require 'rails_helper'

RSpec.describe Group, type: :model do
  let(:user) { create(:user) }
  let(:group) { create(:group, owner: user) }

  describe "validations" do
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(500) }
  end

  describe "associations" do
    it { should belong_to(:owner).class_name('User') }
    it { should have_many(:user_groups).dependent(:destroy) }
    it { should have_many(:users).through(:user_groups) }
    it { should have_many(:memos).dependent(:destroy) }
    it { should have_many(:invitations).dependent(:destroy) }
  end

  describe "scopes" do
    let(:other_user) { create(:user) }
    let!(:owned_group) { create(:group, owner: user) }
    let!(:other_group) { create(:group, owner: other_user) }

    it ".owned_by" do
      expect(Group.owned_by(user)).to include(owned_group)
      expect(Group.owned_by(user)).not_to include(other_group)
    end
  end

  describe "#members" do
    let(:member) { create(:user) }
    before { group.users << member }

    it "returns all members of the group" do
      expect(group.members).to include(user, member)
    end
  end

  describe "#member?" do
    let(:member) { create(:user) }
    let(:non_member) { create(:user) }
    before { group.users << member }

    it "returns true if the user is a member" do
      expect(group.member?(member)).to be true
    end

    it "returns false if the user is not a member" do
      expect(group.member?(non_member)).to be false
    end
  end

  describe "#role_for" do
    let(:admin) { create(:user) }
    let(:member) { create(:user) }
    before do
      group.user_groups.create(user: admin, role: 'admin')
      group.user_groups.create(user: member, role: 'member')
    end

    it "returns 'owner' for the owner" do
      expect(group.role_for(user)).to eq('owner')
    end

    it "returns the correct role for other members" do
      expect(group.role_for(admin)).to eq('admin')
      expect(group.role_for(member)).to eq('member')
    end
  end
end
