terraform {
  required_providers {
    splunk = {
      source = "splunk/splunk"
      //version = "1.0.0"
    }
  }
}
variable "SPLUNK_PASSWORD" {type = string}
variable "SPLUNK_USERNAME" {type = string}
variable "SPLUNK_URL" {type = string}


provider "splunk" {
url = var.SPLUNK_URL
username = var.SPLUNK_USERNAME
password = var.SPLUNK_URL
}

resource "splunk_saved_searches" "saved" {
  name                      = "Sentinel_Hard_Failed_Search"
  search                    = <<EOT
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
| table User Run Time Policy Log
EOT

}



resource "splunk_data_ui_views" "dashboardUI" {
  name     = "TFC_NICO"
  eai_data = <<EOF
  <form version="1.1">
  <label>Nico's Label</label>
  <!-- SPLUNK WILL ALWAYS MOVE THIS BASE SEARCH UP HERE -->
  <search id="filtered_result_set_base_search">
    <query>
      source="terraform_cloud" sourcetype="terraform_cloud" auth.accessor_id=$auth.accessor_id$ resource.type=$resource.type$ resource.action=$resource.action$
        | table auth.accessor_id, resource.id, resource.type, resource.action, auth.type, _time, timestamp, processed_timestamp
    </query>
    <earliest>$time_picker.earliest$</earliest>
    <latest>$time_picker.latest$</latest>
  </search>
  <fieldset submitButton="false" autoRun="true">
    <input type="time" token="time_picker_data_visualizations" searchWhenChanged="true">
      <label>Time Picker for Data Visualizations</label>
      <default>
        <earliest>0</earliest>
        <latest></latest>
      </default>
    </input>
  </fieldset>
  <row>
    <panel>
      <single id="total_policy_checks">
        <title>Total Policy Checks</title>
        <search>
          <query>
            <!-- Querying off resource.type policy_check seems to only apply to overrides -->
            source="terraform_cloud" sourcetype="terraform_cloud" resource.action="policy_checked"
              | stats count as result
              | rename count AS "Total Policy Checks"
              | fields - resource.type
          </query>
          <earliest>$time_picker_data_visualizations.earliest$</earliest>
          <latest>$time_picker_data_visualizations.latest$</latest>
        </search>
        <option name="colorMode">block</option>
        <option name="height">251</option>
        <option name="rangeColors">["0x623CE4","0x623CE4"]</option>
        <option name="rangeValues">[0]</option>
        <option name="underLabel">Total Policy Checks</option>
        <option name="useColors">1</option>
      </single>
    </panel>
    <panel>
      <single id="total_policy_check_overrides">
        <title>Total Policy Check Overrides</title>
        <search>
          <query>
            source="terraform_cloud" sourcetype="terraform_cloud" resource.type="policy_check" resource.action="override"
              | stats count as result
              | rename count AS "Total Policy Check Overrides"
              | fields - resource.type
          </query>
          <earliest>$time_picker_data_visualizations.earliest$</earliest>
          <latest>$time_picker_data_visualizations.latest$</latest>
        </search>
        <option name="colorMode">block</option>
        <option name="height">251</option>
        <option name="rangeColors">["0x623CE4","0x623CE4"]</option>
        <option name="rangeValues">[0]</option>
        <option name="underLabel">Total Policy Check Overrides</option>
        <option name="useColors">1</option>
      </single>
    </panel>
    <panel>
      <single id="total_runs_applied">
        <title>Total Runs Applied</title>
        <search>
          <query>
            source="terraform_cloud" sourcetype="terraform_cloud" resource.type="run" resource.action="applied"
              | stats count as result
              | rename count AS "Total Runs Applied"
              | fields - resource.type
          </query>
          <earliest>$time_picker_data_visualizations.earliest$</earliest>
          <latest>$time_picker_data_visualizations.latest$</latest>
        </search>
        <option name="colorMode">block</option>
        <option name="height">251</option>
        <option name="rangeColors">["0x623CE4","0x623CE4"]</option>
        <option name="rangeValues">[0]</option>
        <option name="underLabel">Total Runs Applied</option>
        <option name="useColors">1</option>
      </single>
    </panel>
  </row>
  <row>
    <panel>
      <chart>
        <title>Policy Check Overrides Filtered by Time</title>
        <search>
          <query>
            source="terraform_cloud" sourcetype="terraform_cloud" resource.type="policy_check" resource.action="override"
            <!--CAN ONLY STRFTIME ON _TIME-->
            <!--TYPICALLY DO NOT WANT TO STRFTIME BUT FORMATTING WAS A DESIGN REQUIREMENT HERE FOR CUSTOMER LEGIBILITY-->
              | eval formatted_time=strftime(_time, "%b %d, %Y")
              | table resource.type, resource.action, _time, timestamp, formatted_time
              | stats count by formatted_time
              | rename formatted_time AS "Time"
              | rename resource.action AS "Overrides"
              | rename count AS "Occurrences"
              | rename resource.type AS "Resource Operation"
          </query>
          <earliest>$time_picker_data_visualizations.earliest$</earliest>
          <latest>$time_picker_data_visualizations.latest$</latest>
        </search>
        <option name="charting.axisLabelsX.majorLabelStyle.rotation">-90</option>
        <option name="charting.chart">column</option>
        <option name="charting.drilldown">none</option>
        <option name="charting.fieldColors">{"Occurrences":#623CE4}</option>
      </chart>
    </panel>
    <panel>
      <chart>
        <title>Top 5 Policy Sets Filtered by Time</title>
        <search>
          <query>
            source="terraform_cloud" sourcetype="terraform_cloud" resource.type="policy_set"
              | table resource.type, resource.id, _time, timestamp, processed_timestamp
              | stats count by resource.id
              | eventstats sum(count) as resource_sum by resource.id
              | sort 5 -resource_sum
              | rename resource.id AS "Resource Operation ID"
              | rename processed_timestamp AS "Time"
              | rename count AS "Occurrences"
              | fields - _time
              | fields - timestamp
              | fields - resource_sum
          </query>
          <earliest>$time_picker_data_visualizations.earliest$</earliest>
          <latest>$time_picker_data_visualizations.latest$</latest>
        </search>
        <option name="charting.chart">bar</option>
        <option name="charting.drilldown">none</option>
        <option name="charting.fieldColors">{"Occurrences":#623CE4}</option>
      </chart>
    </panel>
  </row>
  <row>
    <panel>
      <single>
        <title>Resource Operations Total Filtered by Time</title>
        <search>
          <query>
            source="terraform_cloud" sourcetype="terraform_cloud" resource
              | table resource.type,_time,timestamp, processed_timestamp
              | stats count as result
          </query>
          <earliest>$time_picker_data_visualizations.earliest$</earliest>
          <latest>$time_picker_data_visualizations.latest$</latest>
        </search>
        <option name="colorMode">block</option>
        <option name="drilldown">none</option>
        <option name="rangeColors">["0x623CE4","0x623CE4"]</option>
        <option name="rangeValues">[0]</option>
        <option name="refresh.display">progressbar</option>
        <option name="underLabel">Total Resource Operations</option>
        <option name="useColors">1</option>
      </single>
      <chart>
        <title>Occurrences Filtered by Time</title>
        <search>
          <query>
            source="terraform_cloud" sourcetype="terraform_cloud" resource
            | table resource.type,resource.action, _time, timestamp, processed_timestamp
            | stats count by processed_timestamp
            | rename processed_timestamp As "Time"
            | rename count AS "Occurrences"
          </query>
          <earliest>$time_picker_data_visualizations.earliest$</earliest>
          <latest>$time_picker_data_visualizations.latest$</latest>
        </search>
        <option name="charting.axisY.scale">log</option>
        <option name="charting.chart">area</option>
        <option name="charting.drilldown">none</option>
        <option name="charting.fieldColors">{"Occurrences":#623CE4}</option>
      </chart>
    </panel>
    <panel>
      <chart>
        <title>Total Action Occurrences Filtered by Time</title>
        <search>
          <query>
            source="terraform_cloud" sourcetype="terraform_cloud" resource
              | table resource.action, _time, timestamp, processed_timestamp
              | stats count by resource.action
              | rename processed_timestamp AS "Time"
              | rename resource.action AS "Action"
              | rename count AS "Occurrences"
          </query>
          <earliest>$time_picker_data_visualizations.earliest$</earliest>
          <latest>$time_picker_data_visualizations.latest$</latest>
        </search>
        <option name="charting.axisLabelsX.majorLabelStyle.rotation">90</option>
        <option name="charting.chart">column</option>
        <option name="charting.drilldown">none</option>
        <option name="charting.fieldColors">{"Occurrences":#623CE4}</option>
        <option name="charting.layout.splitSeries">1</option>
        <option name="height">429</option>
      </chart>
    </panel>
  </row>
  <row>
    <panel>
      <title>Filtered Results</title>
      <input type="dropdown" token="auth.accessor_id">
        <label>By User ID</label>
        <search base="filtered_result_set_base_search">
          <query>
            | stats count by auth.accessor_id
          </query>
        </search>
        <fieldForLabel>auth.accessor_id</fieldForLabel>
        <fieldForValue>auth.accessor_id</fieldForValue>
        <choice value="*">All</choice>
        <default>*</default>
        <initialValue>*</initialValue>
      </input>
      <input type="dropdown" token="resource.id">
        <label>By Resource Operation ID</label>
        <search base="filtered_result_set_base_search">
          <query>
            | stats count by resource.id
          </query>
        </search>
        <fieldForLabel>resource.id</fieldForLabel>
        <fieldForValue>resource.id</fieldForValue>
        <choice value="*">All</choice>
        <default>*</default>
        <initialValue>*</initialValue>
      </input>
      <input type="dropdown" token="resource.type">
        <label>By Resource Operation</label>
        <search base="filtered_result_set_base_search">
          <query>
            | stats count by resource.type
          </query>
        </search>
        <fieldForLabel>resource.type</fieldForLabel>
        <fieldForValue>resource.type</fieldForValue>
        <choice value="*">All</choice>
        <default>*</default>
        <initialValue>*</initialValue>
      </input>
      <input type="dropdown" token="resource.action">
        <label>By Action</label>
        <search base="filtered_result_set_base_search">
          <query>
            | stats count by resource.action
          </query>
        </search>
        <fieldForLabel>resource.action</fieldForLabel>
        <fieldForValue>resource.action</fieldForValue>
        <choice value="*">All</choice>
        <default>*</default>
        <initialValue>*</initialValue>
      </input>
      <input type="time" token="time_picker" searchWhenChanged="true">
        <label>Time Picker</label>
        <default>
          <earliest>0</earliest>
          <latest></latest>
        </default>
      </input>
    </panel>
  </row>
  <row>
    <panel>
      <table>
        <title>Filtered Result Set</title>
        <search base="filtered_result_set_base_search">
          <query>
            | search auth.accessor_id=$auth.accessor_id$ resource.id=$resource.id$ resource.type=$resource.type$ resource.action=$resource.action$
            | rename auth.accessor_id AS "User ID"
            | rename resource.id AS "Resource Operation ID"
            | rename resource.type AS "Resource Operation"
            | rename resource.action AS "Action"
            | rename auth.type AS "User Type"
            | rename processed_timestamp AS "Time"
            | fields - _time
            | fields - timestamp
          </query>
        </search>
        <option name="drilldown">cell</option>
        <option name="rowNumbers">true</option>
        <option name="totalsRow">true</option>
      </table>
    </panel>
  </row>
</form>
  EOF
  acl {
    owner = "admin"
    app   = "search"
  }

}


