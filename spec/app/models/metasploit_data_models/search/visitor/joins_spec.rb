require 'spec_helper'

describe MetasploitDataModels::Search::Visitor::Joins do
  subject(:visitor) do
    described_class.new
  end

  it_should_behave_like 'Metasploit::Concern.run'

  context '#visit' do
    subject(:visit) do
      visitor.visit(node)
    end

    context 'with Metasploit::Model::Search::Group::Intersection' do
      let(:children) do
        2.times.collect { |n|
          double("Child #{n}")
        }
      end

      let(:node) do
        Metasploit::Model::Search::Group::Intersection.new(
            :children => children
        )
      end

      it 'should visit each child' do
        # needed for call to visit subject
        visitor.should_receive(:visit).with(node).and_call_original

        children.each do |child|
          visitor.should_receive(:visit).with(child).and_return([])
        end

        visit
      end

      it 'should return Array of all child visits' do
        child_visits = []

        visitor.should_receive(:visit).with(node).and_call_original

        children.each_with_index do |child, i|
          child_visit = ["Visited Child #{i}"]
          visitor.stub(:visit).with(child).and_return(child_visit)
          child_visits.concat(child_visit)
        end

        visit.should == child_visits
      end
    end

    union_classes = [
        Metasploit::Model::Search::Group::Union,
        Metasploit::Model::Search::Operation::Union
    ]

    union_classes.each do |union_class|
      context "with #{union_class}" do
        let(:node) do
          union_class.new(
              children: children
          )
        end

        context 'with children' do
          context 'without child joins' do
            let(:children) do
              Array.new(2) {
                Metasploit::Model::Search::Operator::Attribute.new
              }
            end

            it { should == [] }
          end

          context 'with association and attribute' do
            let(:association) do
              FactoryGirl.generate :metasploit_model_search_operator_association_association
            end

            let(:association_operator) do
              Metasploit::Model::Search::Operator::Association.new(
                  association: association
              )
            end

            let(:attribute_operator) do
              Metasploit::Model::Search::Operator::Attribute.new
            end

            let(:children) do
              [
                  association_operator,
                  attribute_operator
              ]
            end

            it { should == [] }
          end

          context 'with the same child join for all' do
            let(:association) do
              FactoryGirl.generate :metasploit_model_search_operator_association_association
            end

            let(:association_operator) do
              Metasploit::Model::Search::Operator::Association.new(
                  association: association
              )
            end

            let(:children) do
              Array.new(2) {
                association_operator
              }
            end

            it 'should include association' do
              visit.should include association
            end
          end

          context 'with union of intersections' do
            let(:disjoint_associations) do
              Array.new(2) {
                FactoryGirl.generate :metasploit_model_search_operator_association_association
              }
            end

            let(:first_associations) do
              disjoint_associations[0, 1] + common_associations
            end

            let(:first_association_operators) do
              first_associations.collect { |association|
                Metasploit::Model::Search::Operator::Association.new(
                    association: association
                )
              }
            end

            let(:second_associations) do
              disjoint_associations[1, 1] + common_associations
            end

            let(:second_association_operators) do
              second_associations.collect { |association|
                Metasploit::Model::Search::Operator::Association.new(
                    association: association
                )
              }
            end

            let(:children) do
              [first_association_operators, second_association_operators].collect { |grandchildren|
                Metasploit::Model::Search::Group::Intersection.new(
                    children: grandchildren
                )
              }
            end

            context 'with a common subset of child join' do
              let(:common_associations) do
                Array.new(2) {
                  FactoryGirl.generate :metasploit_model_search_operator_association_association
                }
              end

              it 'should include common associations' do
                common_associations.each do |association|
                  visit.should include(association)
                end
              end

              it 'should not include disjoint associations' do
                disjoint_associations.each do |association|
                  visit.should_not include(association)
                end
              end
            end

            context 'without a common subset of child joins' do
              let(:common_associations) do
                []
              end

              it { should == [] }
            end
          end
        end

        context 'without children' do
          let(:children) do
            []
          end

          it { should == [] }
        end
      end
    end

    operation_classes = [
        Metasploit::Model::Search::Operation::Boolean,
        Metasploit::Model::Search::Operation::Date,
        Metasploit::Model::Search::Operation::Integer,
        Metasploit::Model::Search::Operation::Null,
        Metasploit::Model::Search::Operation::Set::Integer,
        Metasploit::Model::Search::Operation::Set::String,
        Metasploit::Model::Search::Operation::String
    ]

    operation_classes.each do |operation_class|
      context "with #{operation_class}" do
        it_should_behave_like 'MetasploitDataModels::Search::Visitor::Includes#visit with Metasploit::Model::Search::Operation::Base' do
          let(:node_class) do
            operation_class
          end
        end
      end
    end

    context 'with Metasploit::Model::Search::Operator::Association' do
      let(:association) do
        FactoryGirl.generate :metasploit_model_search_operator_association_association
      end

      let(:node) do
        Metasploit::Model::Search::Operator::Association.new(
            :association => association
        )
      end

      it 'should include association' do
        visit.should include(association)
      end
    end

    context "with Metasploit::Model::Search::Operator::Attribute" do
      let(:node) do
        Metasploit::Model::Search::Operator::Attribute.new
      end

      it { should == [] }
    end

    context 'with Metasploit::Model::Search::Query#tree' do
      let(:node) do
        query.tree
      end

      let(:query) do
        Metasploit::Model::Search::Query.new(
            :formatted => formatted,
            :klass => klass
        )
      end

      context 'Metasploit::Model::Search:Query#klass' do
        context 'with Mdm::Host' do
          let(:klass) {
            Mdm::Host
          }


          context 'with name' do
            let(:name) do
              FactoryGirl.generate :mdm_host_name
            end

            let(:formatted) do
              "name:\"#{name}\""
            end

            it { should be_empty }
          end

          context 'with services.name' do
            let(:name) do
              FactoryGirl.generate :mdm_service_name
            end

            let(:formatted) do
              "services.name:\"#{name}\""
            end

            it { should include :services }
          end
        end
      end
    end
  end
end