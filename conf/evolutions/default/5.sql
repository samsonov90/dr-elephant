#
# Copyright 2016 LinkedIn Corp.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not
# use this file except in compliance with the License. You may obtain a copy of
# the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#

# --- !Ups

/**
 * This table identifies algo to be used for the optimization metric (Resource, time) and job type (Pig, Hive).
 * In general there should be one algo for one job type, but framework supports multiple algos for one row as well.
 */
CREATE TABLE IF NOT EXISTS tuning_algorithm (
  id int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Auto increment unique id',
  job_type enum('PIG','HIVE','SPARK') NOT NULL COMMENT 'Job type e.g. pig, hive, spark',
  optimization_algo enum('PSO') NOT NULL COMMENT 'optimization algorithm name e.g. PSO',
  optimization_algo_version int(11) NOT NULL COMMENT 'algo version',
  optimization_metric enum('RESOURCE','EXECUTION_TIME') DEFAULT NULL COMMENT 'metric to be optimized',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ,
  PRIMARY KEY (id),
  UNIQUE KEY tuning_algorithm_u1 (optimization_algo, optimization_algo_version)
) ENGINE=InnoDB;

INSERT INTO tuning_algorithm(id, job_type, optimization_algo, optimization_algo_version, optimization_metric, created_ts, updated_ts)
VALUES (1, 'PIG', 'PSO', '1', 'RESOURCE', current_timestamp(0), current_timestamp(0));

/**
 * This table represents hadoop parameters to be optimized for each algo in tuning_algorithm.
 * For example mapreduce.map.memory.mb, mapreduce.task.io.sort.mb etc.
 */
CREATE TABLE IF NOT EXISTS tuning_parameter (
  id int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Auto increment unique id',
  param_name varchar(100) NOT NULL COMMENT 'name of the hadoop parameter e.g. mapreduce.task.io.sort.mb ',
  tuning_algorithm_id int(10) unsigned NOT NULL COMMENT 'Foreign key from tuning_algorithm table',
  default_value double NOT NULL COMMENT 'default value of the parameter in hadoop cluster',
  min_value double NOT NULL COMMENT 'minimum value to be used for the parameter',
  max_value double NOT NULL COMMENT 'maximum value to be used for the parameter',
  step_size double NOT NULL COMMENT 'step size to be used for the parameter',
  is_derived tinyint(4) NOT NULL COMMENT 'Is this the derived parameter for e.g. mapreduce.map.java.opts ',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT tuning_parameter_ibfk_1 FOREIGN KEY (tuning_algorithm_id) REFERENCES tuning_algorithm (id)
) ENGINE=InnoDB;

INSERT INTO tuning_parameter (id, param_name, tuning_algorithm_id, default_value, min_value, max_value, step_size, is_derived, created_ts, updated_ts) VALUES
(1,'mapreduce.task.io.sort.mb',1,100,50,1920,50, 0, current_timestamp(0), current_timestamp(0)),
(2,'mapreduce.map.memory.mb',1,2048,1536,8192,128, 0, current_timestamp(0), current_timestamp(0)),
(3,'mapreduce.task.io.sort.factor',1,10,10,150,10 ,0, current_timestamp(0), current_timestamp(0)),
(4,'mapreduce.map.sort.spill.percent',1,0.8,0.6,0.9,0.1, 0, current_timestamp(0), current_timestamp(0)),
(5,'mapreduce.reduce.memory.mb',1,2048,1536,8192,128, 0, current_timestamp(0), current_timestamp(0)),
(6,'pig.maxCombinedSplitSize',1,536870912,536870912,536870912,128, 0, current_timestamp(0), current_timestamp(0)),
(7,'mapreduce.reduce.java.opts',1,1536,1152,6144,128, 1, current_timestamp(0), current_timestamp(0)),
(8,'mapreduce.map.java.opts',1,1536,1152,6144,128, 1, current_timestamp(0), current_timestamp(0)),
(9,'mapreduce.input.fileinputformat.split.maxsize',1,536870912,536870912,536870912,128, 1, current_timestamp(0), current_timestamp(0));

create index index_tp_algo_id on tuning_parameter (tuning_algorithm_id);

/**
 * This table represent flow of the job.
 */
CREATE TABLE IF NOT EXISTS flow_definition (
  id int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Auto increment unique id',
  flow_def_id varchar(700) NOT NULL COMMENT 'unique flow definition id from scheduler like azkaban, oozie, appworx etc',
  flow_def_url varchar(700) NOT NULL COMMENT 'flow definition URL from scheduler like azkaban, oozie, appworx etc',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY flow_definition_u1 (flow_def_id(100))
) ENGINE=InnoDB AUTO_INCREMENT=10000;

/**
 * This table represent the job to be optimized. This table contains general info other than auto tuning related
 * information. Broken job definition info in two table, as this can be used for Dr Elephant basic info.
 * As not all jobs will be enabled for auto tuning.
 */
CREATE TABLE IF NOT EXISTS job_definition (
  id int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Auto increment unique id',
  job_def_id varchar(700) NOT NULL COMMENT 'unique job definition id from scheduler like azkaban, oozie etc',
  job_def_url varchar(700) NOT NULL COMMENT 'job definition URL from scheduler like azkaban, oozie, appworx etc',
  flow_definition_id int(10) unsigned NOT NULL COMMENT 'foreign key from flow_definition table',
  job_name varchar(700) DEFAULT NULL COMMENT 'name of the job',
  scheduler varchar(100) NOT NULL COMMENT 'name of the scheduler like azkaban. oozie ',
  username varchar(100) NOT NULL COMMENT 'name of the user',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY job_definition_u1 (job_def_id(100)) ,
  CONSTRAINT job_definition_ibfk_1 FOREIGN KEY (flow_definition_id) REFERENCES flow_definition (id)
) ENGINE=InnoDB AUTO_INCREMENT=100000;

create index index_jd_flow_definition_id on job_definition (flow_definition_id);

/**
 * This table represent the job to be optimized and contains information required for auto tuning only.
 */
CREATE TABLE IF NOT EXISTS tuning_job_definition (
  job_definition_id int(10) unsigned NOT NULL COMMENT 'foreign key from job_definition table',
  client varchar(100) NOT NULL COMMENT 'client who is using this. sometime same as scheduler.',
  tuning_algorithm_id int(10) unsigned NOT NULL COMMENT 'foreign key from tuning_algorithm table. algorithm to be used for tuning this job',
  tuning_enabled tinyint(4) NOT NULL COMMENT 'auto tuning is enabled or not ',
  average_resource_usage double DEFAULT NULL COMMENT 'average resource usage when optimization started on this job',
  average_execution_time double DEFAULT NULL COMMENT 'average execution time (excluding delay) when optimization started on this job',
  average_input_size_in_bytes bigint(20) DEFAULT NULL COMMENT 'Average input size in bytes when optimization started on this job',
  allowed_max_resource_usage_percent double DEFAULT NULL COMMENT 'Limit on resource usage, For ex 150 means it should not go beyond 150% ',
  allowed_max_execution_time_percent double DEFAULT NULL COMMENT 'Limit on execution time, For ex 150 means it should not go beyond 150% ',
  tuning_disabled_reason text NULL COMMENT 'reason for disabling tuning, if any',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT tuning_job_definition_ibfk_1 FOREIGN KEY (job_definition_id) REFERENCES job_definition (id),
  CONSTRAINT tuning_job_definition_ibfk_2 FOREIGN KEY (tuning_algorithm_id) REFERENCES tuning_algorithm (id)
) ENGINE=InnoDB;

create index index_tjd_job_definition_id on tuning_job_definition (job_definition_id);
create index index_tjd_tuning_algorithm_id on tuning_job_definition (tuning_algorithm_id);

/**
 * This table represent one execution of a flow.
 */
CREATE TABLE IF NOT EXISTS flow_execution (
  id int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Auto increment unique id',
  flow_exec_id varchar(700) NOT NULL COMMENT 'unique flow execution id from scheduler like azkaban, oozie etc ',
  flow_exec_url varchar(700) NOT NULL COMMENT 'execution url from scheduler like azkaban, oozie etc',
  flow_definition_id int(10) unsigned NOT NULL COMMENT 'foreign key from flow_definition table',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT flow_execution_ibfk_1 FOREIGN KEY (flow_definition_id) REFERENCES flow_definition (id)
) ENGINE=InnoDB AUTO_INCREMENT=1000;

create index index_fe_flow_definition_id on flow_execution (flow_definition_id);

/**
 * This table represent jobs from one execution of a flow. Contains information about execution of a job other than auto
 * tuning related info. Broken execution related info in two table, as this can be used for Dr Elephant basic info.
 * As not all jobs will be enabled for auto tuning.
 */
CREATE TABLE IF NOT EXISTS job_execution (
  id int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Auto increment unique id',
  job_exec_id varchar(700) NOT NULL COMMENT 'unique job execution id from scheduler like azkaban, oozie etc',
  job_exec_url varchar(700) NOT NULL COMMENT 'job execution url from scheduler like azkaban, oozie etc',
  job_definition_id int(10) unsigned NOT NULL COMMENT 'foreign key from job_definition table',
  flow_execution_id int(10) unsigned NOT NULL COMMENT 'foreign key from flow_execution table',
  execution_state enum('SUCCEEDED','FAILED','NOT_STARTED','IN_PROGRESS','CANCELLED') NOT NULL COMMENT 'current state of execution of the job ',
  resource_usage double DEFAULT NULL COMMENT 'resource usage in GB Hours for this execution of the job',
  execution_time double DEFAULT NULL COMMENT 'execution time excluding delay for this execution of the job',
  input_size_in_bytes bigint(20) DEFAULT NULL COMMENT 'input size in bytes for this execution of the job',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT job_execution_ibfk_1 FOREIGN KEY (job_definition_id) REFERENCES job_definition (id),
  CONSTRAINT job_execution_ibfk_2 FOREIGN KEY (flow_execution_id) REFERENCES flow_execution (id)
) ENGINE=InnoDB AUTO_INCREMENT=1000;

create index index_je_job_exec_id on job_execution (job_exec_id(100));
create index index_je_job_exec_url on job_execution (job_exec_url(100));
create index index_je_job_definition_id on job_execution (job_definition_id);
create index index_je_flow_execution_id on job_execution (flow_execution_id);

/**
 * This table represent jobs from one execution of a flow and contains auto tuning related information.
 * This one execution is corresponding to one set of parameters.
 */
CREATE TABLE IF NOT EXISTS job_suggested_param_set (
  id int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Auto increment unique id',
  job_definition_id int(10) unsigned NOT NULL COMMENT 'foreign key from job_definition table',
  tuning_algorithm_id int(10) unsigned NOT NULL COMMENT 'foreign key from tuning_algorithm table',
  param_set_state enum('CREATED','SENT','EXECUTED','FITNESS_COMPUTED','DISCARDED') NOT NULL COMMENT 'state of this execution parameter set',
  are_constraints_violated tinyint(4) default 0 NOT NULL COMMENT 'are constraints violated for the parameter set',
  is_param_set_default tinyint(4) DEFAULT 0 NOT NULL COMMENT 'Is parameter set default',
  is_param_set_best tinyint(4) DEFAULT 0 NOT NULL COMMENT 'Is parameter set best',
  fitness double DEFAULT NULL COMMENT 'fitness of this parameter set',
  fitness_job_execution_id int(10) unsigned NULL COMMENT 'foreign key from job_execution table',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  CONSTRAINT job_suggested_param_set_f1 FOREIGN KEY (tuning_algorithm_id) REFERENCES tuning_algorithm (id),
  -- The following statement is commented as it leads to unit test failures though it works fine when deployed.
  -- This is happening because unlike mysql, h2 database doesn't support nullable foreign keys.
  -- CONSTRAINT job_suggested_param_set_f2 FOREIGN KEY (fitness_job_execution_id) REFERENCES job_execution (id),
  CONSTRAINT job_suggested_param_set_f3 FOREIGN KEY (job_definition_id) REFERENCES job_definition (id)
) ENGINE=InnoDB AUTO_INCREMENT=1000;

create index index_tje_job_definition_id on job_suggested_param_set (job_definition_id);
create index index_tje_tuning_algorithm_id on job_suggested_param_set (tuning_algorithm_id);

/**
 * Internal table for optimization algorithm. Stores the current state of job to be optimized/
 */
CREATE TABLE IF NOT EXISTS job_saved_state (
  job_definition_id int(10) unsigned NOT NULL COMMENT 'foreign key from job_definition table',
  saved_state blob NOT NULL COMMENT 'current state',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (job_definition_id),
  CONSTRAINT job_saved_state_f1 FOREIGN KEY (job_definition_id) REFERENCES job_definition (id)
) ENGINE=InnoDB;


/**
 * Stores the suggested parameter value corresponding to one execution of the job.
 */
CREATE TABLE IF NOT EXISTS job_suggested_param_value (
  id int(10) unsigned NOT NULL AUTO_INCREMENT COMMENT 'Auto increment unique id',
  job_suggested_param_set_id int(10) unsigned NOT NULL COMMENT 'foreign key from job_suggested_param_set table',
  tuning_parameter_id int(10) unsigned NOT NULL COMMENT 'foreign key from tuning_parameter table',
  param_value double NOT NULL COMMENT 'suggested value of the parameter',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY job_suggested_param_value_u1 (job_suggested_param_set_id, tuning_parameter_id),
  CONSTRAINT job_suggested_param_value_f1 FOREIGN KEY (job_suggested_param_set_id) REFERENCES job_suggested_param_set (id),
  CONSTRAINT job_suggested_param_value_f2 FOREIGN KEY (tuning_parameter_id) REFERENCES tuning_parameter (id)
) ENGINE=InnoDB AUTO_INCREMENT=1000;

create index index_jspv_tuning_parameter_id on job_suggested_param_value (tuning_parameter_id);

/**
 * Stores the mapping of job execution and corresponding parameter set
 */

CREATE TABLE IF NOT EXISTS tuning_job_execution_param_set (
  job_suggested_param_set_id int(10) unsigned NOT NULL COMMENT 'foreign key from job_suggested_param_set table',
  job_execution_id int(10) unsigned NOT NULL COMMENT 'foreign key from job_execution table',
  tuning_enabled tinyint(4) NOT NULL COMMENT 'Is tuning enabled for the execution',
  created_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_ts timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY tuning_job_execution_param_set_u1 (job_suggested_param_set_id, job_execution_id),
  CONSTRAINT tuning_job_execution_param_set_f1 FOREIGN KEY (job_suggested_param_set_id) REFERENCES job_suggested_param_set (id),
  CONSTRAINT tuning_job_execution_param_set_f2 FOREIGN KEY (job_execution_id) REFERENCES job_execution (id)
) ENGINE=InnoDB;

# --- !Downs
drop table tuning_job_execution_param_set;
drop table job_suggested_param_value;
drop table job_saved_state;
drop table job_suggested_param_set;
drop table tuning_job_definition;
drop table job_execution;
drop table flow_execution;
drop table job_definition;
drop table flow_definition;
drop table tuning_parameter;
drop table tuning_algorithm;
