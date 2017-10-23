class Account
  attr_accessor :name, :balance, :account_number, :overdraft_limit

  def initialize(name, balance, account_number, overdraft_limit)
    @name = name
    @balance = balance
    @account_number = account_number
    @overdraft_limit = overdraft_limit
  end

  def valid?
    return false if account_number.length != 15
    country_code = account_number[0..2]
    return false if country_code != "CAT"

    check_sum = account_number[3..4].to_i
    id = account_number[5..-1]


    char_array = id.split("")
    while char_array.count > 0
      chr = char_array.first
      if ('a'..'z').to_a.include? chr
        if char_array.include? chr.upcase
          char_array.delete_at(char_array.index(chr.upcase))
          char_array.delete_at(char_array.index(chr))
        else
          return false
        end
      end

      if ('A'..'Z').to_a.include? chr
        if char_array.include? chr.downcase
          char_array.delete_at(char_array.index(chr.downcase))
          char_array.delete_at(char_array.index(chr))
        else
          return false
        end
      end
    end

    sum = 0
    (id + "CAT00").each_byte do |c|
      sum += c
    end

    sum %= 97
    return false if check_sum != (98 - sum)

    return true
  end

  def valid_overdraft?(sum)
    (balance - sum) >= -overdraft_limit
  end
end

class Transaction
  attr_accessor :from, :to, :value, :timestamp

  def initialize(from, to, value, timestamp)
    @from = from
    @to = to
    @value = value
    @timestamp = timestamp
  end

  def apply
    from.balance -= value
    to.balance += value
  end
end

def main
  input = []
  accounts = []
  transactions = []

  File.open(ARGV[0], 'r') do |file|
    file.each_line do |line|
      input << line
    end
  end

  input.reverse!

  num_accounts = input.pop.to_i
  (0...num_accounts).to_a.each do
    account_data = input.pop.split(" ")
    accounts << Account.new(account_data[0], account_data[2].to_i, account_data[1], account_data[3].to_i)
    accounts.last.valid?
  end

  num_transactions = input.pop.to_i
  (0...num_transactions).to_a.each do
    transaction_data = input.pop.split(" ")
    from_acc = accounts.find{|a| a.account_number == transaction_data[0]}
    to_acc = accounts.find{|a| a.account_number == transaction_data[1]}
    transactions << Transaction.new(from_acc, to_acc, transaction_data[2].to_i, transaction_data[3].to_i)
  end

  transactions.sort_by{|t| t.timestamp}.each do |t| 
    next if !t.from.valid? || !t.to.valid? || !t.from.valid_overdraft?(t.value)
    t.apply
  end

  accounts = accounts.select{|a| a.valid?}
  File.open("#{ARGV[0].split(".")[0]}-res.txt", 'w') do |file|
    file << accounts.count.to_s + "\n"
    accounts.each do |acc|
      file << "#{acc.name} #{acc.balance}\n"
    end
  end
end

main()
