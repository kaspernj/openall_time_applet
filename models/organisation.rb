class Openall_time_applet::Models::Organisation < Knj::Datarow
  def self.update_cache(d, args)
    res = nil
    args[:oata].oa_conn do |conn|
      res = conn.request(:getAllOrganisationsForUser)
    end
    
    res.each do |org_data|
      org = self.ob.get_by(:Organisation, {"openall_uid" => org_data["uid"]})
      org_data = {
        :openall_uid => org_data["uid"],
        :name => org_data["name"]
      }
      
      if org
        org.update(org_data)
      else
        org = self.ob.add(:Organisation, org_data)
      end
    end
  end
end