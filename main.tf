terraform {
  required_providers {
    splunk = {
      source = "splunk/splunk"
      //version = "1.0.0"
    }
  }
}
variable "SPLUNK_PASSWORD" {type = "string"}
variable "SPLUNK_USERNAME" {type = "string"}
variable "SPLUNK_URL" {type = "string"}


provider "splunk" {
url = var.SPLUNK_URL
username = var.SPLUNK_USERNAME
password = var.SPLUNK_URL
}

resource "splunk_data_ui_views" "tf_cloud_dashboard" {
  name     = "Terraform Cloud Audit Blab"
  eai_data = <<EOF
  <dashboard version="1.1">
    <label>Table Element</label>
    <description>Create a simple table using the dashboard editor.</description>
    <row>
        <table>
            <title>Top Sourcetypes (Last 24 hours)</title>
            <search>
                <query>
  source="terraform_cloud" sourcetype="terraform_cloud" resource.action="hard_failed"
| spath resource.meta.run.id output=Run 
| spath auth.description output=User
| spath resource.meta.sentinel.data.sentinel-policy-networking.policies{} output=policies 
| mvexpand policies 
| spath input=policies trace.rules.main.position.filename output=filename 
| spath input=policies result output=value 
| where value="false" AND match(filename,"^\..hard") 
| spath input=policies trace.print output=error_message 
| rename filename AS Policy, error_message AS Log, timestamp AS Time
| table User Run Time Policy Log</query>
            </search>
            <option name="wrap">true</option>
            <option name="rowNumbers">true</option>
            <option name="dataOverlayMode">none</option>
            <option name="drilldown">cell</option>
            <option name="count">10</option>
        </table>
    </row>
</dashboard>
  EOF
  acl {
    owner = "admin"
    app   = "search"
  }
}



