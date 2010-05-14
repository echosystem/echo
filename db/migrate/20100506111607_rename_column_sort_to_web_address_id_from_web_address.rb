class RenameColumnSortToWebAddressIdFromWebAddress < ActiveRecord::Migration
  def self.up
    add_column :web_addresses, :web_address_type_id, :integer
    WebAddress.all.each do |web_address|
      web_address_type = web_address.sort.to_i
      puts "former #{web_address_type}"
      web_address_type += 1 unless web_address_type == 99
      puts "Enum Key: #{EnumKey.find_by_key_and_name(web_address_type, "web_address_types").inspect}"
      web_address.web_address_type = EnumKey.find_by_key_and_name(web_address_type, "web_address_types")
      web_address.save
      puts "later #{web_address.web_address_type_id.to_s}"
    end
    #remove_column :web_addresses, :sort
#    rename_column :web_addresses, :sort, :web_address_type_id
    
  end

  def self.down
    rename_column :web_addresses, :web_address_type_id, :sort
  end
end
