# frozen_string_literal: true

namespace :generate do

  task :members, [:number] => [:environment] do |_t, args|
    args.with_defaults(:number => 10)

    Kernel.puts "Creating members ..."
    @members = Bench::Factories.create_list(:member, args[:number].to_i)

    Kernel.puts "Depositing funds ..."

    Currency.find_each do |c|
      @members.each do |m|
        Bench::Factories.create(:deposit, member_id: m.id, currency_id: c.id)
      end
    end
  end
end
