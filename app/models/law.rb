# encoding: utf-8
# == Schema Information
#
# Table name: laws
#
#  id         :integer          not null, primary key
#  label      :string(255)      not null
#  title      :string(255)      not null
#  content    :text
#  state      :string(255)      not null
#  position   :integer
#  submitter  :integer          not null
#  submitted  :datetime
#  enacted    :datetime
#  signed     :datetime
#  created_at :datetime
#  updated_at :datetime
#

class Law < ActiveRecord::Base
  attr_accessible :label, :title, :content, :state, :position, :submitter, :submitted, :enacted, :signed, :refused, :druh

  has_many :polls
  has_many :users, :through => :polls

  belongs_to :user, :foreign_key => :submitter

  validates_presence_of :content, :title

  STATE = %w(Zarazen Projednavan Schvalen Zamitnut Podepsan Odmitnout Platny)
  SYSTEM_LAW = %w(odvolanie_imp)


  def self.create_label
    label = 'IZ' + Aplikace::VEK + '-'
    cislo = (Law.count + 1).to_s
    until cislo.length == 5
      cislo.insert(0, '0')
    end
    label += cislo
    return label
  end

  def self.create_position
    max_pos = Law.zarazene.maximum(:position).to_i
    max_pos += 1
    return max_pos
  end

  #SYSTEM zakon na odvolanie imp
  def self.odvolej_imperatora(submitter)
	  Law.new(:submitter => submitter.id, :content => Constant.odvolanie_imperatora_zakon_body, :title => Constant.odvolanie_imperatora_zakon_title, :druh => Law::SYSTEM_LAW[0], :label => self.create_label, :state => Law::STATE[1], :enacted => Date.today).save
  end

  def self.zakon_navrhnuty(druh)
	  if Law.where(:druh => druh, :state => Law::STATE[1]).first
		  true
	  else
		  false
	  end
  end


  #SYSTEM zakony maju submittera 1

  def vyhodnot_zakon
    if self.druh
	    self.handle_system_law
    else
	    if self.vyhodnot_hlasy
		    if self.refused?
			    self.update_attribute(:state, Law::STATE[6])
			    Landsraad.zapis_operaci("Byl uzakonen znovu voleny zakon #{self.label} - #{self.title} pomerem: #{self.pomer_hlasu}.")
		    else
	      self.update_attribute(:state, Law::STATE[2])
	      Landsraad.zapis_operaci("Byl schvalen zakon #{self.label} - #{self.title} pomerem: #{self.pomer_hlasu}.")
		    end
	    else
	      self.update_attribute(:state, Law::STATE[3])
	      Landsraad.zapis_operaci("Zakon #{self.label} - #{self.title} byl zamitnut pomerem: #{self.pomer_hlasu}.")
	    end
    end
  end

  def vyhodnot_hlasy
	  hlasy_pro = self.polls.pro.count
	  hlasy_proti = self.polls.proti.count
	  zdrzelo_se = self.polls.zdrzelo.count

	  celkem = hlasy_pro + hlasy_proti + zdrzelo_se

	  puts "pro"
	  puts hlasy_pro
	  puts "proti"
	  puts hlasy_proti
	  puts "zdrzelo se"
	  puts zdrzelo_se
	  puts "celkem"
	  puts celkem

	  hlasy_pro > hlasy_proti && hlasy_pro > ((self.refused? ? 0.6 : 0.5) * celkem)
  end

  def handle_system_law
	  case self.druh
		  when Law::SYSTEM_LAW[0]
			   if self.vyhodnot_hlasy
				   self.update_attribute(:state, Law::STATE[6])
				   User.imperator.update_attribute(:emperor, false)
           User.clenove_dvora.each { |u|
             u.zapis_operaci('Imperátor a jeho dvůr byl odvolán')
           }
           User.clenove_dvora.update_all(:court => false, :vezir => false)
				   Imperium.zapis_operaci("Pokus o odvolání byl úspěšný poměrem: #{self.pomer_hlasu}.")
			   else
				   Imperium.zapis_operaci("Pokus o odvolání Imperátora byl zamítnut pomárem: #{self.pomer_hlasu}.")
			   end
	  end
  end

  def pomer_hlasu
    pro = self.polls.pro.count
    proti = self.polls.proti.count
    zdrzelo = self.polls.zdrzelo.count

    return pro.to_s + '/' + proti.to_s + ' (' + zdrzelo.to_s + ')'

  end

  def zahlasovane(user)
    if self.polls.where(:user_id => user).first
      self.polls.where(:user_id => user).first.choice
    else
      false
    end
  end


  def imp_podepis(volba, user)
    if volba == 'Ano'
      self.update_attributes(:signed => Time.now, :state => Law::STATE[4])
      Landsraad.zapis_hlasu_imp(user.id, "Byl podepsan zakon #{self.label} - #{self.title} .")
    elsif volba == 'Ne'
	    Message.system_msg(Constant.odmietnutie_zakona_msg,"Vas zakon byl zamitnut",self.user.nick)
      self.update_attributes(:refused => true, :state => Law::STATE[5])
      Landsraad.zapis_hlasu_imp(user.id, "Byl zamitnout zakon #{self.label} - #{self.title} .")
    end
  end

  scope :zarazene, where(:state => Law::STATE[0])
  scope :projednavane, where(:state => Law::STATE[1])
  scope :schvalene, where(:state => Law::STATE[2])
  scope :zamitnute, where(:state => Law::STATE[3])
  scope :podepsane, where(:state => Law::STATE[4])
  scope :odmitnute, where(:state => Law::STATE[5])
  scope :platne, where(:state => Law::STATE[6])

  scope :submited, lambda { |user| where(:submitter => user.id) }

  scope :seradit, order(:position, :submitted, :enacted, :signed).includes(:users)
end
