# frozen_string_literal: true

module Inferno
  module Sequence
    class USCore310ImmunizationSequence < SequenceBase
      title 'Immunization Tests'

      description 'Verify that Immunization resources on the FHIR server follow the US Core Implementation Guide'

      test_id_prefix 'USCI'

      requires :token, :patient_id
      conformance_supports :Immunization

      def validate_resource_item(resource, property, value)
        case property

        when 'patient'
          value_found = resolve_element_from_path(resource, 'patient.reference') { |reference| [value, 'Patient/' + value].include? reference }
          assert value_found.present?, 'patient on resource does not match patient requested'

        when 'status'
          value_found = resolve_element_from_path(resource, 'status') { |value_in_resource| value.split(',').include? value_in_resource }
          assert value_found.present?, 'status on resource does not match status requested'

        when 'date'
          value_found = resolve_element_from_path(resource, 'occurrence') { |date| validate_date_search(value, date) }
          assert value_found.present?, 'date on resource does not match date requested'

        end
      end

      details %(
        The #{title} Sequence tests `#{title.gsub(/\s+/, '')}` resources associated with the provided patient.
      )

      @resources_found = false

      test :unauthorized_search do
        metadata do
          id '01'
          name 'Server rejects Immunization search without authorization'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html#behavior'
          description %(
            A server SHALL reject any unauthorized requests by returning an HTTP 401 unauthorized response code.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Immunization, [:search])

        @client.set_no_auth
        omit 'Do not test if no bearer token set' if @instance.token.blank?

        search_params = {
          'patient': @instance.patient_id
        }

        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        @client.set_bearer_token(@instance.token)
        assert_response_unauthorized reply
      end

      test :search_by_patient do
        metadata do
          id '02'
          name 'Server returns expected results from Immunization search by patient'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(

            A server SHALL support searching by patient on the Immunization resource

          )
          versions :r4
        end

        search_params = {
          'patient': @instance.patient_id
        }

        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)

        @resources_found = reply&.resource&.entry&.any? { |entry| entry&.resource&.resourceType == 'Immunization' }

        skip 'No Immunization resources appear to be available. Please use patients with more information.' unless @resources_found

        @immunization = reply.resource.entry
          .find { |entry| entry&.resource&.resourceType == 'Immunization' }
          .resource
        @immunization_ary = fetch_all_bundled_resources(reply.resource)
        save_resource_ids_in_bundle(versioned_resource_class('Immunization'), reply)
        save_delayed_sequence_references(@immunization_ary)
        validate_search_reply(versioned_resource_class('Immunization'), reply, search_params)
      end

      test :search_by_patient_date do
        metadata do
          id '03'
          name 'Server returns expected results from Immunization search by patient+date'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+date on the Immunization resource

              including support for these date comparators: gt, lt, le, ge
          )
          versions :r4
        end

        skip 'No Immunization resources appear to be available. Please use patients with more information.' unless @resources_found

        search_params = {
          'patient': @instance.patient_id,
          'date': get_value_for_search_param(resolve_element_from_path(@immunization_ary, 'occurrence'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        validate_search_reply(versioned_resource_class('Immunization'), reply, search_params)
        assert_response_ok(reply)

        ['gt', 'lt', 'le', 'ge'].each do |comparator|
          comparator_val = date_comparator_value(comparator, search_params[:date])
          comparator_search_params = { 'patient': search_params[:patient], 'date': comparator_val }
          reply = get_resource_by_params(versioned_resource_class('Immunization'), comparator_search_params)
          validate_search_reply(versioned_resource_class('Immunization'), reply, comparator_search_params)
        end
      end

      test :search_by_patient_status do
        metadata do
          id '04'
          name 'Server returns expected results from Immunization search by patient+status'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(

            A server SHOULD support searching by patient+status on the Immunization resource

          )
          versions :r4
        end

        skip 'No Immunization resources appear to be available. Please use patients with more information.' unless @resources_found

        search_params = {
          'patient': @instance.patient_id,
          'status': get_value_for_search_param(resolve_element_from_path(@immunization_ary, 'status'))
        }
        search_params.each { |param, value| skip "Could not resolve #{param} in given resource" if value.nil? }

        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        validate_search_reply(versioned_resource_class('Immunization'), reply, search_params)
        assert_response_ok(reply)
      end

      test :read_interaction do
        metadata do
          id '05'
          name 'Server returns correct Immunization resource from Immunization read interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          description %(
            A server SHALL support the Immunization read interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Immunization, [:read])
        skip 'No Immunization resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_read_reply(@immunization, versioned_resource_class('Immunization'))
      end

      test :vread_interaction do
        metadata do
          id '06'
          name 'Server returns correct Immunization resource from Immunization vread interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Immunization vread interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Immunization, [:vread])
        skip 'No Immunization resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_vread_reply(@immunization, versioned_resource_class('Immunization'))
      end

      test :history_interaction do
        metadata do
          id '07'
          name 'Server returns correct Immunization resource from Immunization history interaction'
          link 'https://www.hl7.org/fhir/us/core/CapabilityStatement-us-core-server.html'
          optional
          description %(
            A server SHOULD support the Immunization history interaction.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Immunization, [:history])
        skip 'No Immunization resources could be found for this patient. Please use patients with more information.' unless @resources_found

        validate_history_reply(@immunization, versioned_resource_class('Immunization'))
      end

      test 'Server returns Provenance resources from Immunization search by patient + _revIncludes: Provenance:target' do
        metadata do
          id '08'
          link 'https://www.hl7.org/fhir/search.html#revinclude'
          description %(
            A Server SHALL be capable of supporting the following _revincludes: Provenance:target
          )
          versions :r4
        end

        search_params = {
          'patient': @instance.patient_id
        }

        search_params['_revinclude'] = 'Provenance:target'
        reply = get_resource_by_params(versioned_resource_class('Immunization'), search_params)
        assert_response_ok(reply)
        assert_bundle_response(reply)
        provenance_results = fetch_all_bundled_resources(reply.resource).select { |resource| resource.resourceType == 'Provenance' }
        skip 'No Provenance resources were returned from this search' unless provenance_results.present?
        provenance_results.each { |reference| @instance.save_resource_reference('Provenance', reference.id) }
      end

      test 'Immunization resources returned conform to US Core R4 profiles' do
        metadata do
          id '09'
          link 'http://hl7.org/fhir/us/core/StructureDefinition/us-core-immunization'
          description %(

            This test checks if the resources returned from prior searches conform to the US Core profiles.
            This includes checking for missing data elements and valueset verification.

          )
          versions :r4
        end

        skip 'No Immunization resources appear to be available. Please use patients with more information.' unless @resources_found
        test_resources_against_profile('Immunization')
      end

      test 'All must support elements are provided in the Immunization resources returned.' do
        metadata do
          id '10'
          link 'http://www.hl7.org/fhir/us/core/general-guidance.html#must-support'
          description %(

            US Core Responders SHALL be capable of populating all data elements as part of the query results as specified by the US Core Server Capability Statement.
            This will look through all Immunization resources returned from prior searches to see if any of them provide the following must support elements:

            Immunization.status

            Immunization.statusReason

            Immunization.vaccineCode

            Immunization.patient

            Immunization.occurrenceDateTime

            Immunization.occurrenceString

            Immunization.primarySource

          )
          versions :r4
        end

        skip 'No Immunization resources appear to be available. Please use patients with more information.' unless @resources_found

        must_support_elements = [
          'Immunization.status',
          'Immunization.statusReason',
          'Immunization.vaccineCode',
          'Immunization.patient',
          'Immunization.occurrenceDateTime',
          'Immunization.occurrenceString',
          'Immunization.primarySource'
        ]

        missing_must_support_elements = must_support_elements.reject do |path|
          truncated_path = path.gsub('Immunization.', '')
          @immunization_ary&.any? do |resource|
            resolve_element_from_path(resource, truncated_path).present?
          end
        end

        skip_if missing_must_support_elements.present?,
                "Could not find #{missing_must_support_elements.join(', ')} in the #{@immunization_ary&.length} provided Immunization resource(s)"

        @instance.save!
      end

      test 'Every reference within Immunization resource is valid and can be read.' do
        metadata do
          id '11'
          link 'http://hl7.org/fhir/references.html'
          description %(
            This test checks if references found in resources from prior searches can be resolved.
          )
          versions :r4
        end

        skip_if_known_not_supported(:Immunization, [:search, :read])
        skip 'No Immunization resources appear to be available. Please use patients with more information.' unless @resources_found

        validate_reference_resolutions(@immunization)
      end
    end
  end
end
