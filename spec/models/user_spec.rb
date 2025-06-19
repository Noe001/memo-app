require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'バリデーション' do
    it 'has a valid factory' do
      expect(build(:user)).to be_valid
    end

    describe 'name' do
      it 'presence: true' do
        user = build(:user, name: nil)
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include("can't be blank")
      end

      it 'length: minimum 2' do
        user = build(:user, name: 'a')
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include('is too short (minimum is 2 characters)')
      end

      it 'length: maximum 50' do
        user = build(:user, name: 'a' * 51)
        expect(user).not_to be_valid
        expect(user.errors[:name]).to include('is too long (maximum is 50 characters)')
      end
    end

    describe 'email' do
      it 'presence: true' do
        user = build(:user, email: nil)
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include("can't be blank")
      end

      it 'uniqueness: true' do
        create(:user, email: 'test@example.com')
        user = build(:user, email: 'test@example.com')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('has already been taken')
      end

      it 'format validation' do
        user = build(:user, email: 'invalid-email')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('is invalid')
      end

      it 'case insensitive uniqueness' do
        create(:user, email: 'test@example.com')
        user = build(:user, email: 'TEST@EXAMPLE.COM')
        expect(user).not_to be_valid
        expect(user.errors[:email]).to include('has already been taken')
      end
    end

    describe 'password' do
      it 'presence: true' do
        user = build(:user, password: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include("can't be blank")
      end

      it 'minimum length: 8' do
        user = build(:user, password: 'short', password_confirmation: 'short')
        expect(user).not_to be_valid
        expect(user.errors[:password]).to include('is too short (minimum is 8 characters)')
      end

      it 'valid password with 8 characters' do
        user = build(:user, password: 'password', password_confirmation: 'password')
        expect(user).to be_valid
      end

      it 'valid simple password' do
        user = build(:user, password: 'simplepass', password_confirmation: 'simplepass')
        expect(user).to be_valid
      end
    end

    describe 'password_confirmation' do
      it 'presence: true on create' do
        user = build(:user, password_confirmation: nil)
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include("can't be blank")
      end

      it 'matches password' do
        user = build(:user, password: 'Password123!', password_confirmation: 'Different123!')
        expect(user).not_to be_valid
        expect(user.errors[:password_confirmation]).to include("doesn't match Password")
      end
    end
  end

  describe 'associations' do
    it { should have_many(:memos).dependent(:destroy) }
    it { should have_many(:sessions).dependent(:destroy) }
  end

  describe 'callbacks' do
    describe 'before_save :downcase_email' do
      it 'converts email to lowercase before saving' do
        user = create(:user, email: 'TEST@EXAMPLE.COM')
        expect(user.email).to eq('test@example.com')
      end
    end
  end

  describe 'secure password' do
    let(:user) { create(:user, password: 'password123') }

    it 'authenticates with correct password' do
      expect(user.authenticate('password123')).to eq(user)
    end

    it 'returns false with incorrect password' do
      expect(user.authenticate('wrongpassword')).to be_falsey
    end
  end

  describe 'factory traits' do
    it 'creates user with memos' do
      user = create(:user, :with_memos)
      expect(user.memos.count).to eq(3)
    end

    it 'creates user with invalid email' do
      user = build(:user, :invalid_email)
      expect(user).not_to be_valid
    end

    it 'creates user with weak password' do
      user = build(:user, :weak_password)
      expect(user).not_to be_valid
    end
  end
end
