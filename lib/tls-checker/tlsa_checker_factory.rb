# frozen_string_literal: true

module TLSChecker
  class TLSACheckerFactory
    def initialize
      @resolver = Resolv::DNS.new
    end

    def tlsa_checkers_for(certificate_checker)
      res = []

      resource = "_#{certificate_checker.port}._tcp.#{certificate_checker.hostname}."

      @resolver.getresources(resource, Resolv::DNS::Resource::IN::ANY).each do |rr|
        # XXX: Should we check the RRSIG here, or can we assume that the resolver
        # should have failed if it could not verify the response?
        next unless rr.class.name.match?(/::Type52_Class1$/)

        record = Resolv::DNS::Resource::IN::TLSA.new(rr.data)
        next unless record.end_entity?

        checker = TLSAChecker.new(record, certificate_checker)
        # Since a single domain may have different certificates on different
        # addresses, we are not interested in reporting failures here: a server
        # with 3 certificates on 3 IP addresses is expected to have 3 TLSA
        # records in the DNS, each one being valid for a different certificate.
        #
        # By adding only valid certificates, we can still detect problems when
        # events expire.
        next unless checker.certificate_match_tlsa_record?

        res << checker
      end

      res
    end
  end
end
